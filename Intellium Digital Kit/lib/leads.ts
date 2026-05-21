import { createServerSupabaseClient } from "@/lib/supabase/server";
import { normalizeText, normalizeUrl } from "@/lib/utils";

export async function findDuplicateLead({
  businessName,
  businessLink
}: {
  businessName: string;
  businessLink?: string | null;
}) {
  const supabase = await createServerSupabaseClient();
  const normalizedName = normalizeText(businessName);
  const normalizedLink = businessLink ? normalizeUrl(businessLink) : null;

  const { data: nameMatch } = await supabase
    .from("leads")
    .select("id, business_name, business_link, status")
    .eq("normalized_business_name", normalizedName)
    .limit(1)
    .maybeSingle();

  if (normalizedLink) {
    const { data: linkMatch } = await supabase
      .from("leads")
      .select("id, business_name, business_link, status")
      .eq("normalized_business_link", normalizedLink)
      .limit(1)
      .maybeSingle();

    return {
      nameMatch,
      linkMatch,
      hasDuplicate: Boolean(nameMatch || linkMatch)
    };
  }

  return {
    nameMatch,
    linkMatch: null,
    hasDuplicate: Boolean(nameMatch)
  };
}

export async function createProofSignedUrl(path: string | null) {
  if (!path) {
    return null;
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase.storage
    .from("lead-proofs")
    .createSignedUrl(path, 60 * 60);

  return data?.signedUrl ?? null;
}
