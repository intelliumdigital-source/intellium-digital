import { loadEnvConfig } from "@next/env";
import { createClient } from "@supabase/supabase-js";

const TABLES = ["profiles", "business_profiles", "posts", "services"] as const;

function logSuccess(message: string) {
  console.log(`✅ ${message}`);
}

function logFailure(message: string) {
  console.error(`❌ ${message}`);
}

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  if (typeof error === "object" && error !== null && "message" in error) {
    const message = error.message;
    if (typeof message === "string") {
      return message;
    }
  }

  return "Unknown error";
}

function getErrorCode(error: unknown) {
  if (typeof error === "object" && error !== null && "code" in error) {
    const code = error.code;
    if (typeof code === "string") {
      return code;
    }
  }

  return "";
}

function isConnectionError(error: unknown) {
  const message = getErrorMessage(error).toLowerCase();

  return [
    "failed to fetch",
    "fetch failed",
    "network",
    "enotfound",
    "getaddrinfo",
    "invalid url",
  ].some((part) => message.includes(part));
}

function isMissingTableError(error: unknown) {
  const message = getErrorMessage(error).toLowerCase();
  const code = getErrorCode(error);

  if (code === "42P01") {
    return true;
  }

  return (
    message.includes("could not find the table") ||
    (message.includes("relation") && message.includes("does not exist"))
  );
}

function reportTableCheck(table: string, error: unknown) {
  if (!error) {
    logSuccess(`${table}: Table exists / accessible`);
    return true;
  }

  if (isMissingTableError(error)) {
    logFailure(`${table}: Table missing or schema not applied yet`);
    return false;
  }

  logFailure(`${table}: ${getErrorMessage(error)}`);
  return false;
}

async function main() {
  loadEnvConfig(process.cwd());

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url) {
    logFailure("Missing env value: NEXT_PUBLIC_SUPABASE_URL");
  } else {
    logSuccess("Supabase URL found");
  }

  if (!anonKey) {
    logFailure("Missing env value: NEXT_PUBLIC_SUPABASE_ANON_KEY");
  } else {
    logSuccess("Supabase anon key found");
  }

  if (!url || !anonKey) {
    process.exitCode = 1;
    return;
  }

  const supabase = createClient(url, anonKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  let hasFailures = false;

  try {
    const { error: profilesError } = await supabase
      .from("profiles")
      .select("id", { count: "exact", head: true });

    if (profilesError && isConnectionError(profilesError)) {
      logFailure(
        "Could not connect to Supabase. Check your URL, anon key, and internet connection.",
      );
      process.exitCode = 1;
      return;
    }

    logSuccess("Connected to Supabase");

    hasFailures = !reportTableCheck("profiles", profilesError);

    for (const table of TABLES.slice(1)) {
      const { error } = await supabase
        .from(table)
        .select("id", { count: "exact", head: true });

      if (!reportTableCheck(table, error)) {
        hasFailures = true;
      }
    }
  } catch (error) {
    logFailure(
      `Could not connect to Supabase. ${getErrorMessage(error)}`,
    );
    process.exitCode = 1;
    return;
  }

  if (hasFailures) {
    process.exitCode = 1;
  }
}

void main();
