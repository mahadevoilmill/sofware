<script lang="ts">
  import { supabase } from '$lib/supabase';

  let voucher = {
    department: "",
    person: "",
    voucher_no: "",
    date: "",
    amount_paid: 0
  };

  async function handleSubmit() {
    const { data, error } = await supabase
      .from('bank_payment_vouchers')
      .insert([voucher]);

    if (error) alert(error.message);
    else alert('Voucher added successfully!');
  }
</script>

<h1>Create Voucher</h1>
<form on:submit|preventDefault={handleSubmit}>
  <input bind:value={voucher.department} placeholder="Department" />
  <input bind:value={voucher.person} placeholder="Person" />
  <input bind:value={voucher.voucher_no} placeholder="Voucher No" />
  <input type="date" bind:value={voucher.date} />
  <input type="number" bind:value={voucher.amount_paid} placeholder="Amount" />
  <button type="submit">Submit</button>
</form>
