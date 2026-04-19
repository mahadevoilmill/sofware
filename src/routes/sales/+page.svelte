<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase';
  import { language, translations, financialYear, getFYDateRange } from '$lib/i18n';
  import jsPDF from 'jspdf';
  import autoTable from 'jspdf-autotable';
  import { Plus, Download, Trash2, CheckCircle, Circle, Edit2, FileText } from 'lucide-svelte';

  const t = $derived(translations[$language]);

  let customers = $state<any[]>([]);
  let inventory = $state<any[]>([]);
  let sales = $state<any[]>([]);
  let companySettings = $state<any>(null);
  let showManualProduct = $state(false);
  let showEditForm = $state(false);
  let editingSale = $state<any>(null);
  
  let newSale = $state({
    customer_id: '',
    product_item: '',
    product_name: '',
    quantity: 0,
    unit: 'NOS', // Default unit
    rate: 0,
    gst_rate: 5,
    selling_partner: '',
    payment_mode: 'Cash',
    payment_details: '',
    sale_date: new Date().toISOString().split('T')[0]
  });

  const totalBase = $derived(newSale.quantity * newSale.rate);
  const cgst = $derived((totalBase * (newSale.gst_rate / 2)) / 100);
  const sgst = $derived((totalBase * (newSale.gst_rate / 2)) / 100);
  const total_amount = $derived(totalBase + cgst + sgst);

  onMount(async () => {
    await fetchData();
  });

  $effect(() => {
    if ($financialYear) {
      fetchData();
    }
  });

  async function fetchData() {
    const { start, end } = getFYDateRange($financialYear);
    try {
      console.log('Fetching company settings...');
      const { data: setts } = await supabase.from('company_settings').select('*');
      companySettings = setts?.[0] || null;

      console.log('Fetching customers...');
      const { data: custData, error: custError } = await supabase.from('customers').select('*').order('name');
      if (custError) console.error('Error fetching customers:', custError);
      customers = custData || [];

      console.log('Fetching inventory...');
      // Fetching only oil items for sales, as per the original code.
      const { data: invData, error: invError } = await supabase.from('inventory').select('*').filter('item_name', 'ilike', '%oil%').order('item_name');
      if (invError) console.error('Error fetching inventory:', invError);
      inventory = invData || [];

      console.log('Fetching sales...');
      const { data: salesData, error: salesError } = await supabase
        .from('sales')
        .select(`
          *,
          customers:customer_id(name, address, mobile, gst_number, state_name, state_code),
          inventory:product_item(item_name)
        `)
        .gte('sales_date', start)
        .lte('sales_date', end)
        .order('created_at', { ascending: false });
      
      if (salesError) {
        console.error('Error fetching sales (join failed):', salesError);
        console.log('Retrying sales fetch and mapping manually...');
        
        const { data: simpleSales, error: simpleError } = await supabase.from('sales').select('*').order('created_at', { ascending: false });
        if (simpleError) {
          console.error('Error in simple sales fetch:', simpleError);
          sales = [];
        } else {
          // Manually map IDs to names
          sales = simpleSales.map(sale => ({
            ...sale,
            customers: customers.find(c => c.id === sale.customer_id) || { name: 'N/A' },
            inventory: inventory.find(i => i.id === sale.product_item) || { item_name: sale.product_name || 'N/A' }
          }));
        }
      } else {
        console.log('Fetched sales successfully:', salesData.length, 'records');
        sales = salesData || [];
      }
    } catch (err) {
      console.error('Unexpected error in fetchData:', err);
    }
  }

  async function handleAddSale() {
    // Validation
    if (!newSale.customer_id) {
      alert('Please select a customer');
      return;
    }

    if (newSale.quantity <= 0 || newSale.rate <= 0) {
      alert('Please enter valid quantity and rate');
      return;
    }

    // Determine if using inventory product or manual product
    if (!showManualProduct && !newSale.product_item) {
      alert('Please select a product or switch to manual entry');
      return;
    }

    if (showManualProduct && !newSale.product_name) {
      alert('Please enter product name');
      return;
    }

    const totalBase = newSale.quantity * newSale.rate;
    const cgst = (totalBase * (newSale.gst_rate / 2)) / 100;
    const sgst = (totalBase * (newSale.gst_rate / 2)) / 100;
    const total = totalBase + cgst + sgst;

    // Get next invoice number by finding the highest existing number
    const { data: existingInvoices } = await supabase
      .from('sales')
      .select('invoice_number')
      .order('created_at', { ascending: false })
      .limit(1);

    let nextNum = 1;
    if (existingInvoices && existingInvoices.length > 0) {
      const lastInvoice = existingInvoices[0].invoice_number;
      const lastNum = parseInt(lastInvoice.replace('MAHADEV-', ''), 10);
      nextNum = lastNum + 1;
    }
    const invoice_number = `MAHADEV-${nextNum.toString().padStart(3, '0')}`;

    const saleData: any = {
      invoice_number,
      customer_id: newSale.customer_id,
      quantity: newSale.quantity,
      unit: newSale.unit,
      rate: newSale.rate,
      cgst: cgst,
      sgst: sgst,
      total_amount: total_amount,
      selling_partner: newSale.selling_partner,
      is_done: false,
      sales_date: newSale.sale_date,
      payment_mode: newSale.payment_mode,
      payment_details: newSale.payment_details
    };

    let insertError = false;

    // If inventory product, add product_item and update stock
    if (!showManualProduct && newSale.product_item) {
      saleData.product_item = newSale.product_item;
      
      const { error } = await supabase.from('sales').insert(saleData);

      if (error) {
        console.error('Sale insert error:', error);
        alert('Error adding sale: ' + error.message);
        insertError = true;
      } else {
        // Update stock
        const product = inventory.find(i => i.id === newSale.product_item);
        if (product) {
          await supabase.from('inventory')
            .update({ quantity: product.quantity - newSale.quantity })
            .eq('id', newSale.product_item);
        }
      }
    } else {
      // Manual product - store product name
      saleData.product_name = newSale.product_name;
      
      const { error } = await supabase.from('sales').insert(saleData);
      
      if (error) {
        console.error('Sale insert error:', error);
        alert('Error adding sale: ' + error.message);
        insertError = true;
      }
    }

    if (!insertError) {
      // Reset form
      newSale = { 
        customer_id: newSale.customer_id, 
        product_item: '', 
        product_name: '',
        quantity: 0, 
        rate: 0,
        gst_rate: 5,
        cgst: 0,
        sgst: 0,
        total_amount: 0,
        selling_partner: '',
        payment_mode: 'Cash',
        payment_details: '',
        sale_date: new Date().toISOString().split('T')[0]
      };
      
      // Fetch updated data
      await fetchData();
    }
  }

  function numberToWords(num: number) {
    const a = ['', 'One ', 'Two ', 'Three ', 'Four ', 'Five ', 'Six ', 'Seven ', 'Eight ', 'Nine ', 'Ten ', 'Eleven ', 'Twelve ', 'Thirteen ', 'Fourteen ', 'Fifteen ', 'Sixteen ', 'Seventeen ', 'Eighteen ', 'Nineteen '];
    const b = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    if ((num = num.toString()).length > 9) return 'overflow';
    let n: any = ('000000000' + num).substr(-9).match(/^(\d{2})(\d{2})(\d{2})(\d{1})(\d{2})$/);
    if (!n) return '';
    let str = '';
    str += (Number(n[1]) != 0) ? (a[Number(n[1])] || b[n[1][0]] + ' ' + a[n[1][1]]) + 'Crore ' : '';
    str += (Number(n[2]) != 0) ? (a[Number(n[2])] || b[n[2][0]] + ' ' + a[n[2][1]]) + 'Lakh ' : '';
    str += (Number(n[3]) != 0) ? (a[Number(n[3])] || b[n[3][0]] + ' ' + a[n[3][1]]) + 'Thousand ' : '';
    str += (Number(n[4]) != 0) ? (a[Number(n[4])] || b[n[4][0]] + ' ' + a[n[4][1]]) + 'Hundred ' : '';
    str += (Number(n[5]) != 0) ? ((str != '') ? 'and ' : '') + (a[Number(n[5])] || b[n[5][0]] + ' ' + a[n[5][1]]) + 'Only ' : 'Only ';
    return 'INR ' + str;
  }

  async function generatePDF(sale: any) {
    try {
      const doc = new jsPDF({
        orientation: 'p',
        unit: 'mm',
        format: 'a4'
      });

      const pageWidth = doc.internal.pageSize.getWidth();
      const pageHeight = doc.internal.pageSize.getHeight();
      const margin = 10;
      const contentWidth = pageWidth - (margin * 2);

      // Prepare Seller Data
      const seller = companySettings || {
        company_name: 'MAHADEV OIL MILL',
        address: '902 NAGARDAS NI KHADKI, VASAD, MO NO. 9879944395',
        gstin: '24ADIFS2075H1Z2',
        state_name: 'Gujarat',
        state_code: '24',
        contact_no: '8849735425',
        upi_id: '8849735425@upi',
        logo_url: ''
      };

      // Generate UPI QR Code URL
      const upiUrl = `upi://pay?pa=${seller.upi_id || '8849735425@upi'}&pn=${encodeURIComponent(seller.company_name)}&am=${sale.total_amount}&cu=INR`;
      const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(upiUrl)}`;

      // Helper to load image
      const loadImage = (url: string): Promise<HTMLImageElement> => {
        return new Promise((resolve, reject) => {
          const img = new Image();
          img.crossOrigin = 'anonymous';
          img.onload = () => resolve(img);
          img.onerror = (e) => {
            console.error('Failed to load image:', url, e);
            reject(e);
          };
          img.src = url;
        });
      };

      let qrImage: HTMLImageElement | undefined;
      let logoImage: HTMLImageElement | undefined;

      // Load QR Code
      try {
        qrImage = await loadImage(qrCodeUrl);
      } catch (e) {
        console.warn('Could not load QR code', e);
      }

      // Load Logo
      if (seller.logo_url) {
        try {
          // Use 'alias' to automatically detect format from the HTMLImageElement
          logoImage = await loadImage(seller.logo_url);
        } catch (e) {
          console.warn('Could not load Logo image', e);
        }
      }

      const drawGridInvoice = (title: string, yOffset: number) => {
        let y = margin + yOffset;
        
        // Main Border Box
        doc.setDrawColor(0);
        doc.setLineWidth(0.2);
        doc.rect(margin, y, contentWidth, (pageHeight / 2) - 15);

        // Header Title
        doc.setFontSize(10);
        doc.setFont('helvetica', 'bold');
        doc.text(title, pageWidth / 2, y + 5, { align: 'center' });
        doc.line(margin, y + 7, pageWidth - margin, y + 7);

        y += 7;
        const colMid = margin + (contentWidth / 2);
        
        // Add Logo if exists
        let infoX = margin + 2;
        if (logoImage) {
          try {
            // Use 'alias' to automatically detect format from the HTMLImageElement
            doc.addImage(logoImage, 'JPEG', margin + 2, y + 1, 15, 15);
            infoX = margin + 20; // Shift text to right of logo
          } catch (imgErr) {
            console.error('Error drawing logo on PDF:', imgErr);
          }
        }

        doc.setFontSize(11);
        doc.setFont('helvetica', 'bold');
        doc.text(seller.company_name, infoX, y + 5);
        doc.setFontSize(8);
        doc.setFont('helvetica', 'normal');
        doc.text(seller.address, infoX, y + 9);
        doc.text(`GSTIN/UIN: ${seller.gstin}`, infoX, y + 13);
        doc.text(`State Name: ${seller.state_name}, Code : ${seller.state_code}`, infoX, y + 17);
        doc.text(`Contact: ${seller.contact_no}`, infoX, y + 21);
        
        // Top Right Data Box
        doc.line(colMid, y, colMid, y + 40);
        const rightCol = colMid + (contentWidth / 4);
        
        doc.text('Voucher No.', colMid + 2, y + 4);
        doc.text('Dated', rightCol + 2, y + 4);
        doc.setFont('helvetica', 'bold');
        doc.text(sale.invoice_number, colMid + 2, y + 8);
        doc.text(new Date(sale.sales_date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: '2-digit' }), rightCol + 2, y + 8);
        
        doc.line(colMid, y + 10, pageWidth - margin, y + 10);
        doc.setFont('helvetica', 'normal');
        doc.text('Mode/Terms of Payment', colMid + 2, y + 14);
        doc.setFont('helvetica', 'bold');
        const payModeText = sale.payment_mode || 'Cash';
        const payDetails = sale.payment_details ? ` (${sale.payment_details})` : '';
        doc.text(payModeText + payDetails, colMid + 2, y + 18);
        doc.line(colMid, y + 20, pageWidth - margin, y + 20);
        doc.setFont('helvetica', 'normal');
        doc.text('Buyer\'s Ref./Order No.', colMid + 2, y + 24);
        doc.text('Other References', rightCol + 2, y + 24);
        doc.line(colMid, y + 30, pageWidth - margin, y + 30);
        doc.text('Dispatched through', colMid + 2, y + 34);
        doc.text('Destination', rightCol + 2, y + 34);
        
        y += 40;
        doc.line(margin, y, pageWidth - margin, y);
        
        // Buyer Info
        doc.setFont('helvetica', 'normal');
        doc.text('Buyer (Bill to)', margin + 2, y + 4);
        doc.setFont('helvetica', 'bold');
        doc.text(sale.customers?.name || 'N/A', margin + 2, y + 8);
        doc.setFont('helvetica', 'normal');
        doc.text(sale.customers?.address || '', margin + 2, y + 12);
        doc.text(`GSTIN/UIN: ${sale.customers?.gst_number || ''}`, margin + 2, y + 16);
        doc.text(`State Name: ${sale.customers?.state_name || 'Gujarat'}, Code: ${sale.customers?.state_code || '24'}`, margin + 2, y + 20);
        doc.text(`Contact: ${sale.customers?.mobile || ''}`, margin + 2, y + 24);

        y += 30;
        doc.line(margin, y, pageWidth - margin, y);

        // Table Header
        const cols = {
          si: margin + 5,
          desc: margin + 50,
          hsn: margin + 75,
          qty: margin + 100,
          rate: margin + 125,
          per: margin + 145,
          amt: pageWidth - margin
        };

        doc.setFontSize(7);
        doc.text('SI No.', margin + 1, y + 4);
        doc.text('Description of Goods', margin + 15, y + 4);
        doc.text('HSN/SAC', cols.hsn - 10, y + 4);
        doc.text('Quantity', cols.qty - 10, y + 4);
        doc.text('Rate', cols.rate - 10, y + 4);
        doc.text('per', cols.per - 5, y + 4);
        doc.text('Amount', cols.amt - 10, y + 4);
        
        doc.line(margin, y + 6, pageWidth - margin, y + 6);
        
        // Vertical lines for table
        const tableBottom = y + 50;
        doc.line(margin + 8, y, margin + 8, tableBottom);
        doc.line(cols.hsn - 15, y, cols.hsn - 15, tableBottom);
        doc.line(cols.qty - 15, y, cols.qty - 15, tableBottom);
        doc.line(cols.rate - 15, y, cols.rate - 15, tableBottom);
        doc.line(cols.per - 10, y, cols.per - 10, tableBottom);
        doc.line(cols.amt - 25, y, cols.amt - 25, tableBottom + 15);

        y += 10;
        doc.setFontSize(9);
        doc.text('1', margin + 3, y);
        const product = sale.product_name || sale.inventory?.item_name || 'N/A';
        doc.setFont('helvetica', 'bold');
        doc.text(product, margin + 10, y);
        doc.setFont('helvetica', 'normal');
        doc.text('39233090', cols.hsn - 13, y);
        doc.text(`${sale.quantity} NOS`, cols.qty - 13, y);
        doc.text(sale.rate.toFixed(2), cols.rate - 13, y);
        doc.text('NOS', cols.per - 8, y);
        doc.text( (sale.quantity * sale.rate).toLocaleString('en-IN', {minimumFractionDigits: 2}), cols.amt - 2, y, { align: 'right' });

        y = tableBottom;
        doc.line(margin, y, pageWidth - margin, y);
        
        // Totals Calculation
        const subtotal = sale.quantity * sale.rate;
        const splitRate = (sale.gst_rate || 5) / 2;

        doc.setFontSize(8);
        doc.setFont('helvetica', 'normal');
        
        // Compact summary rows
        y += 5;
        doc.text('Subtotal (Base)', cols.amt - 60, y);
        doc.text(subtotal.toLocaleString('en-IN', {minimumFractionDigits: 2}), cols.amt - 2, y, { align: 'right' });
        
        y += 5;
        doc.text(`CGST (${splitRate}%)`, cols.amt - 60, y);
        doc.text(sale.cgst.toLocaleString('en-IN', {minimumFractionDigits: 2}), cols.amt - 2, y, { align: 'right' });
        
        y += 5;
        doc.text(`SGST (${splitRate}%)`, cols.amt - 60, y);
        doc.text(sale.sgst.toLocaleString('en-IN', {minimumFractionDigits: 2}), cols.amt - 2, y, { align: 'right' });
        
        y += 5;
        doc.line(margin, y, pageWidth - margin, y);
        
        // Grand Total row - repositioned to avoid overlap
        doc.setFont('helvetica', 'bold');
        doc.setFontSize(10);
        y += 7;
        doc.text('Total Amount', margin + 2, y); // Moved far left to description area
        doc.text(`Rs. ${sale.total_amount.toLocaleString('en-IN', {minimumFractionDigits: 2})}`, cols.amt - 2, y, { align: 'right' });
        
        y += 3;
        doc.line(margin, y, pageWidth - margin, y);

        doc.setFontSize(8);
        doc.setFont('helvetica', 'normal');
        doc.text('Amount Chargeable (in words)', margin + 2, y + 4);
        doc.setFont('helvetica', 'bold');
        doc.text(numberToWords(Math.round(sale.total_amount)), margin + 2, y + 8);
        
        y += 20;
        doc.setFont('helvetica', 'normal');
        doc.setFontSize(7);
        doc.text('Company\'s Bank Details', colMid, y + 4);
        doc.text(`Bank Name: ${seller.bank_name || 'N/A'}`, colMid, y + 8);
        doc.text(`A/c No: ${seller.account_no || 'N/A'}`, colMid, y + 12);
        doc.text(`Branch & IFSC Code: ${seller.branch_ifsc || 'N/A'}`, colMid, y + 16);
        
        doc.setFontSize(8);
        doc.text(`for ${seller.company_name}`, pageWidth - margin - 5, y + 25, { align: 'right' });
        
        if (sale.selling_partner) {
          doc.setFont('helvetica', 'italic');
          doc.text(`(Created by: ${sale.selling_partner})`, pageWidth - margin - 5, y + 29, { align: 'right' });
        }
        
        doc.setFont('helvetica', 'bold');
        doc.text('Authorised Signatory', pageWidth - margin - 5, y + 35, { align: 'right' });
        
        // Add QR Code
        if (qrImage) {
          doc.setFontSize(8);
          doc.text('Scan to Pay', colMid - 25, y + 10);
          doc.addImage(qrImage, 'PNG', colMid - 30, y + 12, 25, 25);
        }

        doc.setFontSize(6);
        doc.text('This is a Computer Generated Document', pageWidth / 2, y + 40, { align: 'center' });
      };

      // Single Copy as requested (following the sample provided)
      drawGridInvoice('SALES ORDER', 0);
      
      // Open in new tab for viewing ONLY
      const pdfData = doc.output('bloburl');
      window.open(pdfData, '_blank');
      
    } catch (error: any) {
      console.error('PDF generation error:', error);
      alert('Error generating PDF: ' + error.message);
    }
  }

  async function toggleDone(saleId: string, currentDone: boolean) {
    const { error } = await supabase
      .from('sales')
      .update({ is_done: !currentDone })
      .eq('id', saleId);

    if (!error) {
      await fetchData();
    }
  }

  async function openEditForm(sale: any) {
    editingSale = { ...sale };
    showEditForm = true;
  }

  async function handleUpdateSale() {
    if (!editingSale) return;

    // Recalculate totals
    const totalBase = editingSale.quantity * editingSale.rate;
    const cgst = (totalBase * (editingSale.gst_rate / 2)) / 100;
    const sgst = (totalBase * (editingSale.gst_rate / 2)) / 100;
    const total = totalBase + cgst + sgst;

    const updateData: any = {
      customer_id: editingSale.customer_id,
      quantity: editingSale.quantity,
      rate: editingSale.rate,
      gst_rate: editingSale.gst_rate,
      cgst,
      sgst,
      total_amount: total,
      selling_partner: editingSale.selling_partner,
      sales_date: editingSale.sales_date,
      payment_mode: editingSale.payment_mode,
      payment_details: editingSale.payment_details,
      // If product_item is empty but product_name exists, it's manual
      product_item: editingSale.product_item || null,
      product_name: editingSale.product_item ? null : editingSale.product_name
    };

    const { error } = await supabase
      .from('sales')
      .update(updateData)
      .eq('id', editingSale.id);

    if (!error) {
      showEditForm = false;
      editingSale = null;
      await fetchData();
      alert('Sale updated successfully!');
    } else {
      alert('Error updating sale: ' + error.message);
    }
  }

  async function deleteSale(sale: any) {
    if (!confirm(`Delete invoice ${sale.invoice_number}? This action cannot be undone.`)) {
      return;
    }

    const { error } = await supabase
      .from('sales')
      .delete()
      .eq('id', sale.id);

    if (!error) {
      await fetchData();
      alert('Invoice deleted successfully!');
    } else {
      alert('Error deleting sale: ' + error.message);
    }
  }
</script>

<div class="sales-container">
  <div class="page-header-branding">
    {#if companySettings?.logo_url}
      <img src={companySettings.logo_url} alt="Logo" class="company-logo-ui" />
    {/if}
    <div class="company-info-ui">
      <h2>{t.sales}</h2>
      {#if companySettings}
        <p class="company-name-subtitle">{companySettings.company_name}</p>
        <p class="company-address-subtitle">{companySettings.address}</p>
      {/if}
    </div>
  </div>

  <div class="sale-form-card">
    <div class="form-header">
      <h3>New Invoice</h3>
      <label class="toggle-label">
        <input type="checkbox" bind:checked={showManualProduct} />
        <span>{showManualProduct ? 'Manual Product' : 'From Inventory'}</span>
      </label>
    </div>
    
    <div class="form-grid">
      <div class="input-group">
        <label>{t.customer_name}</label>
        <select bind:value={newSale.customer_id}>
          <option value="">Select Customer</option>
          {#each customers as customer}
            <option value={customer.id}>{customer.name}</option>
          {/each}
        </select>
      </div>

      {#if showManualProduct}
        <div class="input-group">
          <label>Product Name</label>
          <input type="text" bind:value={newSale.product_name} placeholder="Enter product name" />
        </div>
      {:else}
        <div class="input-group">
          <label>{t.product}</label>
          <select bind:value={newSale.product_item}>
            <option value="">Select Product</option>
            {#each inventory as item}
              <option value={item.id}>{item.item_name} ({item.quantity} available)</option>
            {/each}
          </select>
        </div>
      {/if}

      <div class="input-group">
        <label>{t.quantity}</label>
        <input type="number" bind:value={newSale.quantity} min="1" step="0.01" />
      </div>

      <div class="input-group">
        <label>Unit</label>
        <select bind:value={newSale.unit}>
          <option value="NOS">NOS</option>
          <option value="KG">KG</option>
          <option value="LTR">LTR</option>
        </select>
      </div>

      <div class="input-group">
        <label>{t.rate}</label>
        <input type="number" bind:value={newSale.rate} min="1" step="0.01" />
      </div>

      <div class="input-group">
        <label>GST Rate (%)</label>
        <select bind:value={newSale.gst_rate}>
          <option value={0}>0% (Exempt)</option>
          <option value={5}>5% (2.5% CGST + 2.5% SGST)</option>
          <option value={12}>12% (6% CGST + 6% SGST)</option>
          <option value={18}>18% (9% CGST + 9% SGST)</option>
          <option value={28}>28% (14% CGST + 14% SGST)</option>
        </select>
      </div>

      <div class="input-group">
        <label>Sale Date</label>
        <input type="date" bind:value={newSale.sale_date} />
      </div>

      <div class="input-group">
        <label>Selling Partner</label>
        <select bind:value={newSale.selling_partner}>
          <option value="">Select Partner</option>
          {#if companySettings?.partner1_name}
            <option value={companySettings.partner1_name}>{companySettings.partner1_name}</option>
          {/if}
          {#if companySettings?.partner2_name}
            <option value={companySettings.partner2_name}>{companySettings.partner2_name}</option>
          {/if}
        </select>
      </div>

      <div class="input-group">
        <label>Payment Mode</label>
        <select bind:value={newSale.payment_mode}>
          <option value="Cash">Cash</option>
          <option value="Bank">Bank / Cheque</option>
          <option value="Online">Online / UPI</option>
          <option value="Credit">Credit</option>
        </select>
      </div>

      {#if newSale.payment_mode === 'Bank'}
        <div class="input-group">
          <label>Cheque Number / Ref</label>
          <input type="text" bind:value={newSale.payment_details} placeholder="Enter cheque number" />
        </div>
      {:else if newSale.payment_mode === 'Online'}
        <div class="input-group">
          <label>Transaction ID / UPI Ref</label>
          <input type="text" bind:value={newSale.payment_details} placeholder="Enter transaction ID" />
        </div>
      {/if}
      <div class="input-group">
        <label>CGST (₹)</label>
        <input type="text" value={cgst.toFixed(2)} disabled />
      </div>
      <div class="input-group">
        <label>SGST (₹)</label>
        <input type="text" value={sgst.toFixed(2)} disabled />
      </div>
      <div class="input-group full-width"> <!-- Make total amount span full width -->
        <label>Total Amount (₹)</label>
        <input type="text" value={total_amount.toFixed(2)} disabled style="font-weight: bold; font-size: 1.1rem;" />
      </div>
    </div>
    <button class="add-btn" onclick={handleAddSale}>
      <Plus size={18} /> Add Sale
    </button>
  </div>

  {#if showEditForm && editingSale}
    <div class="edit-form-card">
      <div class="form-header">
        <h3>Edit Invoice: {editingSale.invoice_number}</h3>
        <button class="close-btn" onclick={() => { showEditForm = false; editingSale = null; }}>✕</button>
      </div>
      
      <div class="form-grid">
        <div class="input-group">
          <label>Customer</label>
          <select bind:value={editingSale.customer_id}>
            <option value="">Select Customer</option>
            {#each customers as customer}
              <option value={customer.id}>{customer.name}</option>
            {/each}
          </select>
        </div>

        <div class="input-group">
          <label>Product (Inventory)</label>
          <select bind:value={editingSale.product_item} onchange={() => editingSale.product_name = ''}>
            <option value="">Manual Entry (below)</option>
            {#each inventory as item}
              <option value={item.id}>{item.item_name}</option>
            {/each}
          </select>
        </div>

        {#if !editingSale.product_item}
          <div class="input-group">
            <label>Product Name (Manual)</label>
            <input type="text" bind:value={editingSale.product_name} />
          </div>
        {/if}

        <div class="input-group">
          <label>Quantity</label>
          <input type="number" bind:value={editingSale.quantity} step="0.01" />
        </div>

        <div class="input-group">
          <label>Rate</label>
          <input type="number" bind:value={editingSale.rate} step="0.01" />
        </div>

        <div class="input-group">
          <label>GST Rate (%)</label>
          <select bind:value={editingSale.gst_rate}>
            <option value={0}>0% (Exempt)</option>
            <option value={5}>5% (2.5% CGST + 2.5% SGST)</option>
            <option value={12}>12% (6% CGST + 6% SGST)</option>
            <option value={18}>18% (9% CGST + 9% SGST)</option>
            <option value={28}>28% (14% CGST + 14% SGST)</option>
          </select>
        </div>

        <div class="input-group">
          <label>Sale Date</label>
          <input type="date" bind:value={editingSale.sale_date} />
        </div>

        <div class="input-group">
          <label>Selling Partner</label>
          <select bind:value={editingSale.selling_partner}>
            <option value="">Select Partner</option>
            {#if companySettings?.partner1_name}
              <option value={companySettings.partner1_name}>{companySettings.partner1_name}</option>
            {/if}
            {#if companySettings?.partner2_name}
              <option value={companySettings.partner2_name}>{companySettings.partner2_name}</option>
            {/if}
          </select>
        </div>

        <div class="input-group">
          <label>Payment Mode</label>
          <select bind:value={editingSale.payment_mode}>
            <option value="Cash">Cash</option>
            <option value="Bank">Bank / Cheque</option>
            <option value="Online">Online / UPI</option>
            <option value="Credit">Credit</option>
          </select>
        </div>

        {#if editingSale.payment_mode === 'Bank'}
          <div class="input-group">
            <label>Cheque Number / Ref</label>
            <input type="text" bind:value={editingSale.payment_details} />
          </div>
        {:else if editingSale.payment_mode === 'Online'}
          <div class="input-group">
            <label>Transaction ID / UPI Ref</label>
            <input type="text" bind:value={editingSale.payment_details} />
          </div>
        {/if}
      </div>
      <div class="form-actions">
        <button class="btn-submit" onclick={handleUpdateSale}>Update Sale</button>
        <button class="btn-cancel" onclick={() => { showEditForm = false; editingSale = null; }}>Cancel</button>
      </div>
    </div>
  {/if}

  <div class="sales-list">
    <h3>Recent Sales</h3>
    <table>
      <thead>
        <tr>
          <th>Invoice #</th>
          <th>Date</th>
          <th>Customer</th>
          <th>Product</th>
          <th>Total</th>
          <th>Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each sales as sale}
          <tr class={sale.is_done ? 'done' : ''}>
            <td>{sale.invoice_number}</td>
            <td>{new Date(sale.sales_date).toLocaleDateString()}</td>
            <td>{sale.customers?.name}</td>
            <td>{sale.product_name || sale.inventory?.item_name || 'N/A'}</td>
            <td>₹{sale.total_amount.toLocaleString()}</td>
            <td class="status-cell">
              <button 
                class="done-btn"
                onclick={() => toggleDone(sale.id, sale.is_done)}
                title={sale.is_done ? 'Mark as pending' : 'Mark as done'}
              >
                {#if sale.is_done}
                  <CheckCircle size={18} />
                {:else}
                  <Circle size={18} />
                {/if}
              </button>
            </td>
            <td class="actions">
              <button onclick={() => openEditForm(sale)} class="edit-btn" title="Edit Invoice">
                <Edit2 size={16} />
              </button>
              <button onclick={() => generatePDF(sale)} class="pdf-btn" title="Download PDF">
                <Download size={16} />
              </button>
              <button onclick={() => deleteSale(sale)} class="delete-btn" title="Delete Invoice">
                <Trash2 size={16} />
              </button>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<style>
  .sales-container h2 {
    margin: 0;
    color: #2c3e50;
  }

  .page-header-branding {
    display: flex;
    align-items: center;
    gap: 20px;
    margin-bottom: 30px;
    padding: 20px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  .company-logo-ui {
    width: 80px;
    height: 80px;
    object-fit: contain;
    border: 1px solid #eee;
    border-radius: 4px;
  }

  .company-info-ui {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .company-name-subtitle {
    font-weight: bold;
    color: #34495e;
    margin: 0;
    font-size: 1.1rem;
  }

  .company-address-subtitle {
    color: #7f8c8d;
    margin: 0;
    font-size: 0.85rem;
  }

  .sale-form-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    margin-bottom: 30px;
  }

  .edit-form-card {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    margin-bottom: 30px;
    border: 2px solid #3498db;
  }

  .form-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    padding-bottom: 15px;
    border-bottom: 2px solid #ecf0f1;
  }

  .close-btn {
    background: none;
    border: none;
    font-size: 20px;
    cursor: pointer;
    color: #95a5a6;
    padding: 0 10px;
  }

  .close-btn:hover {
    color: #e74c3c;
  }

  .form-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px;
    margin-bottom: 20px;
  }

  .input-group label {
    display: block;
    margin-bottom: 5px;
    font-size: 0.9rem;
    font-weight: 600;
    color: #2c3e50;
  }

  .input-group select, .input-group input {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    font-family: inherit;
  }

  .add-btn {
    background-color: #2ecc71;
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: 4px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: bold;
  }

  .form-actions {
    display: flex;
    gap: 10px;
    margin-top: 15px;
  }

  .btn-submit {
    background: #27ae60;
    color: white;
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: bold;
    font-size: 14px;
  }

  .btn-submit:hover {
    background: #229954;
  }

  .btn-cancel {
    background: #bdc3c7;
    color: #2c3e50;
    padding: 10px 20px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-weight: bold;
    font-size: 14px;
  }

  .btn-cancel:hover {
    background: #95a5a6;
  }

  .toggle-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
  }

  .sales-list {
    background: white;
    padding: 25px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  }

  table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
  }

  th, td {
    padding: 12px;
    text-align: left;
    border-bottom: 1px solid #eee;
  }

  th {
    color: #7f8c8d;
    font-size: 0.9rem;
    text-transform: uppercase;
  }

  .pdf-btn {
    background: none;
    border: 1px solid #3498db;
    color: #3498db;
    padding: 5px;
    border-radius: 4px;
    cursor: pointer;
    margin-right: 5px;
  }

  .pdf-btn:hover {
    background: #3498db;
    color: white;
  }

  tr.done {
    background-color: #ecf0f1;
    opacity: 0.7;
  }

  tr.done td {
    text-decoration: line-through;
    color: #95a5a6;
  }

  .status-cell {
    text-align: center;
  }

  .done-btn {
    background: none;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #95a5a6;
    padding: 5px;
    border-radius: 4px;
    transition: all 0.3s ease;
  }

  .done-btn:hover {
    background: rgba(46, 204, 113, 0.1);
    color: #27ae60;
  }

  tr.done .done-btn {
    color: #27ae60;
  }

  tr.done .done-btn:hover {
    color: #229954;
  }

  .edit-btn {
    background: none;
    border: 1px solid #f39c12;
    color: #f39c12;
    padding: 5px;
    border-radius: 4px;
    cursor: pointer;
    margin-right: 5px;
  }
  .edit-btn:hover {
    background: #f39c12;
    color: white;
  }

  .delete-btn {
    background: none;
    border: 1px solid #e74c3c;
    color: #e74c3c;
    padding: 5px;
    border-radius: 4px;
    cursor: pointer;
    margin-left: 5px;
  }
  .delete-btn:hover {
    background: #e74c3c;
    color: white;
  }
</style>
