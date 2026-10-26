import { supabase } from "./supabase";

async function testConnection() {
  console.log("Testing Supabase connection...");

  const { error } = await supabase
    .from("services")
    .select("*")
    .limit(1);

  if (error) {
    console.error("Supabase query failed:", error.message);
    process.exitCode = 1;
    return;
  }

  console.log("Supabase connection successful!");
  console.log("The services table is accessible.");
}

testConnection().catch(() => {
  console.error("Supabase connection test failed.");
  process.exitCode = 1;
});