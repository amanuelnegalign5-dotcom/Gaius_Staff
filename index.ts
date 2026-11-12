import { withSupabase } from "npm:@supabase/server@1";

function json(body, status = 200) {
  return Response.json(body, { status });
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

    const { supabaseAdmin, userClaims } = ctx;
    const callerId = userClaims?.id;
    if (!callerId) return json({ error: "Authenticated user identity is missing." }, 401);

    // The wrapper verifies the caller's JWT. This extra database check limits
    // account creation to an active Gaius administrator, not just any user.
    const { data: callerProfile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("role,is_active")
      .eq("id", callerId)
      .maybeSingle();

    if (profileError || !callerProfile || callerProfile.role !== "admin" || !callerProfile.is_active) {
      return json({ error: "Administrator permission required." }, 403);
    }

    let body;
    try {
      body = await req.json();
    } catch {
      return json({ error: "Invalid JSON body." }, 400);
    }

    const username = String(body.username ?? "").trim().toLowerCase();
    const fullName = String(body.full_name ?? "").trim();
    const password = String(body.password ?? "");
    const center = String(body.center ?? "HQ").trim();
    const department = String(body.department ?? "Other").trim();

    if (!/^[a-z0-9._-]{3,30}$/.test(username)) {
      return json({ error: "Username must be 3–30 English letters, numbers, dots, underscores, or hyphens." }, 400);
    }
    if (!fullName || fullName.length > 120) return json({ error: "Enter a valid full name." }, 400);
    if (password.length < 10 || password.length > 128) return json({ error: "Password must be at least 10 characters." }, 400);
    if (center.length > 80 || department.length > 80) return json({ error: "Center or department is too long." }, 400);

    const { data: existing, error: lookupError } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("username", username)
      .maybeSingle();
    if (lookupError) return json({ error: "Could not verify username availability." }, 500);
    if (existing) return json({ error: "That username is already in use." }, 409);

    // Username-based synthetic identity; no real mailbox is required.
    const email = `${username}@staff.gaiusministry.org`;
    const { data: created, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { username, full_name: fullName, center, department },
    });
    if (createError || !created.user) {
      return json({ error: createError?.message ?? "Could not create account." }, 400);
    }

    const { error: saveProfileError } = await supabaseAdmin.from("profiles").upsert({
      id: created.user.id,
      username,
      full_name: fullName,
      center,
      department,
      role: "staff",
      is_active: true,
      updated_at: new Date().toISOString(),
    }, { onConflict: "id" });

    if (saveProfileError) {
      await supabaseAdmin.auth.admin.deleteUser(created.user.id);
      return json({ error: "Account was not completed. Check the database trigger and retry." }, 500);
    }

    return json({ ok: true, user_id: created.user.id, username });
  }),
};
