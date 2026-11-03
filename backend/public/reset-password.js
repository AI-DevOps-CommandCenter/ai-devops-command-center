import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const form = document.getElementById("resetForm");
const button = document.getElementById("resetButton");
const message = document.getElementById("message");

const passwordInput = document.getElementById("password");
const confirmPasswordInput = document.getElementById("confirmPassword");

let supabase = null;
let recoveryVerified = false;
let isUpdating = false;

function showMessage(text, type) {
    message.textContent = text;
    message.className = type;
}

function setFormEnabled(enabled) {
    passwordInput.disabled = !enabled;
    confirmPasswordInput.disabled = !enabled;
    button.disabled = !enabled;
}

async function initializeSupabase() {
    try {
        const response = await fetch("/api/auth/config");

        if (!response.ok) {
            throw new Error("Unable to load Supabase configuration.");
        }

        const config = await response.json();

        if (!config.supabaseUrl || !config.supabaseAnonKey) {
            throw new Error("Supabase configuration is incomplete.");
        }

        supabase = createClient(
            config.supabaseUrl,
            config.supabaseAnonKey,
            {
                auth: {
                    autoRefreshToken: true,
                    persistSession: true,
                    detectSessionInUrl: true
                }
            }
        );

        const { data, error } = await supabase.auth.getSession();

        if (error) throw error;

        if (!data.session) {
            showMessage(
                "Invalid or expired recovery link. Please request a new password reset email.",
                "error"
            );

            setFormEnabled(false);
            return;
        }

        recoveryVerified = true;

        window.history.replaceState(
            {},
            document.title,
            window.location.pathname
        );

        setFormEnabled(true);

        showMessage(
            "Recovery link verified successfully. You can now set your new password.",
            "success"
        );

    } catch (error) {
        console.error("Supabase initialization error:", error);

        showMessage(
            "Unable to verify the recovery link. Please try again.",
            "error"
        );

        setFormEnabled(false);
    }
}

form.addEventListener("submit", async (event) => {
    event.preventDefault();

    if (!supabase || !recoveryVerified || isUpdating) {
        showMessage("Your recovery session is not valid.", "error");
        return;
    }

    const password = passwordInput.value;
    const confirmPassword = confirmPasswordInput.value;

    if (password.length < 8) {
        showMessage("Password must contain at least 8 characters.", "error");
        return;
    }

    if (password !== confirmPassword) {
        showMessage("Passwords do not match.", "error");
        return;
    }

    isUpdating = true;
    setFormEnabled(false);
    button.textContent = "Updating Password...";

    try {
        const { error } = await supabase.auth.updateUser({
            password: password
        });

        if (error) throw error;

        recoveryVerified = false;
        form.reset();

        showMessage(
            "Your password has been successfully updated. You can now log in with your new password.",
            "success"
        );

        const { error: signOutError } = await supabase.auth.signOut();

        if (signOutError) {
            console.error("Sign out error:", signOutError.message);
        }

    } catch (error) {
        console.error("Password update error:", error);

        showMessage(
            error.message || "Unable to update password. Please try again.",
            "error"
        );

        recoveryVerified = false;

    } finally {
        isUpdating = false;
        button.textContent = "Reset Password";
        setFormEnabled(recoveryVerified);
    }
});

initializeSupabase();