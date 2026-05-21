import { NextResponse } from "next/server";

import { getCurrentProfile } from "@/lib/auth";
import { findDuplicateLead } from "@/lib/leads";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const session = await getCurrentProfile();

  if (!session.configured) {
    return NextResponse.json(
      {
        hasDuplicate: false,
        message: "Supabase is not configured."
      },
      { status: 200 }
    );
  }

  if (!session.user) {
    return NextResponse.json(
      {
        hasDuplicate: false,
        message: "Unauthorized."
      },
      { status: 401 }
    );
  }

  const { searchParams } = new URL(request.url);
  const businessName = searchParams.get("businessName") ?? "";
  const businessLink = searchParams.get("businessLink") ?? "";

  if (businessName.trim().length < 2 && businessLink.trim().length < 4) {
    return NextResponse.json({
      hasDuplicate: false,
      message: ""
    });
  }

  const duplicateCheck = await findDuplicateLead({ businessName, businessLink });

  if (duplicateCheck.hasDuplicate) {
    return NextResponse.json({
      hasDuplicate: true,
      message: "A matching lead already exists. Double-check before submitting."
    });
  }

  return NextResponse.json({
    hasDuplicate: false,
    message: "No duplicate lead found."
  });
}
