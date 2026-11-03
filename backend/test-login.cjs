
const readline = require("node:readline/promises");
const process = require("node:process");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

async function ask(question) {
  return (await rl.question(question)).trim();
}

async function main() {
  let failed = false;

  try {
    // 1. Get Supabase configuration and test user credentials
    const projectUrlInput = await ask("Supabase Project URL: ");
    const publishableKey = await ask("Supabase Publishable Key: ");
    const email = await ask("Test user email: ");
    const password = await ask("Test user password: ");

    const projectUrl = projectUrlInput.replace(/\/+$/, "");

    if (!projectUrl || !publishableKey || !email || !password) {
      throw new Error("All fields are required.");
    }

    // 2. Validate the Supabase project URL
    let parsedUrl;

    try {
      parsedUrl = new URL(projectUrl);
    } catch {
      throw new Error("Invalid Supabase Project URL.");
    }

    if (
      parsedUrl.protocol !== "https:" ||
      !(
        parsedUrl.hostname === "supabase.co" ||
        parsedUrl.hostname.endsWith(".supabase.co")
      ) ||
      parsedUrl.username ||
      parsedUrl.password ||
      parsedUrl.port ||
      parsedUrl.pathname !== "/" ||
      parsedUrl.search ||
      parsedUrl.hash
    ) {
      throw new Error("Enter a valid HTTPS Supabase Project URL.");
    }

    // 3. Authenticate with Supabase
    console.log("\nLogging in to Supabase...");

    const loginResponse = await fetch(
      `${projectUrl}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: publishableKey,
        },
        body: JSON.stringify({
          email,
          password,
        }),
      }
    );

    let loginData;

    try {
      loginData = await loginResponse.json();
    } catch {
      throw new Error("Supabase returned an invalid response.");
    }

    if (!loginResponse.ok || !loginData.access_token) {
      console.error("\nSupabase login failed.");
      console.error("HTTP status:", loginResponse.status);
      console.error(
        "Message:",
        loginData.msg ||
          loginData.message ||
          loginData.error_description ||
          loginData.error ||
          "Check your login details and Supabase configuration."
      );

      failed = true;
      return;
    }

    console.log("Supabase login successful.");

    const headers = {
      Authorization: `Bearer ${loginData.access_token}`,
    };

    // 4. Define API permission tests
    const serviceId = "48741d41-edba-4ce9-80b7-5019cfb9aaa4";

    const tests = [
      {
        name: "View services",
        method: "GET",
        url: "http://localhost:3000/api/services",
        expectedStatus: 200,
      },
      {
        name: "Create service as a user",
        method: "POST",
        url: "http://localhost:3000/api/services",
        expectedStatus: 403,
        body: {
          name: "Permission Test Service",
          description: "Temporary authorization test",
          environment: "testing",
          status: "healthy",
        },
      },
      {
        name: "Update service as a user",
        method: "PATCH",
        url: `http://localhost:3000/api/services/${serviceId}`,
        expectedStatus: 403,
        body: {
          description: "Authorization test",
        },
      },
      {
        name: "Delete service as a user",
        method: "DELETE",
        url: `http://localhost:3000/api/services/${serviceId}`,
        expectedStatus: 403,
      },
    ];

    // 5. Run tests and record failures
    for (const test of tests) {
      console.log(`\nTest: ${test.name}`);

      try {
        const options = {
          method: test.method,
          headers: { ...headers },
        };

        if (test.body) {
          options.headers["Content-Type"] = "application/json";
          options.body = JSON.stringify(test.body);
        }

        const response = await fetch(test.url, options);
        const responseText = await response.text();

        console.log("HTTP status:", response.status);
        console.log("Response:", responseText);

        if (response.status === test.expectedStatus) {
          console.log("PASS");
        } else {
          console.error(`FAIL: Expected HTTP ${test.expectedStatus}.`);
          failed = true;
        }
      } catch (error) {
        console.error("FAIL:", error.message);
        failed = true;
      }
    }

    console.log(
      failed
        ? "\nPermission tests FAILED."
        : "\nAll permission tests PASSED."
    );
  } catch (error) {
    console.error("\nTest failed:", error.message);
    failed = true;
  } finally {
    rl.close();
    process.exitCode = failed ? 1 : 0;
  }
}

main();
