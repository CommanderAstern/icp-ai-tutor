<script>
  import "../index.scss";
  import { backend } from "$lib/canisters";

  let name = "";
  let role = "";
  let message = "";

  async function onSubmit(event) {
    const enteredName = event.target.name.value;
    const response = await backend.login(enteredName);
    console.log("Test",response.length);
    if (response && response.length > 0) {
      name = enteredName;
      role = response;
      message = `Welcome, ${name}! You are logged in as a ${role}.`;
    } else {
      name = "";
      role = "";
      message = "Error: User not found.";
    }
    return false;
  }
</script>

<main>
  <img src="/logo2.svg" alt="DFINITY logo" />
  <br />
  <br />

  {#if role === ""}
    <form action="#" on:submit|preventDefault={onSubmit}>
      <label for="name">Enter your name: &nbsp;</label>
      <input id="name" alt="Name" type="text" />
      <button type="submit">Login</button>
    </form>
  {:else}
    <section id="greeting">
      <h2>{message}</h2>
      {#if role === "teacher"}
        <!-- Teacher-specific content goes here -->
        <p>You have access to teacher features.</p>
      {:else if role === "student"}
        <!-- Student-specific content goes here -->
        <p>You have access to student features.</p>
      {/if}
      <button on:click={() => { name = ""; role = ""; message = ""; }}>Logout</button>
    </section>
  {/if}
</main>