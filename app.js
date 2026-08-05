import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";
import { SUPABASE_URL, SUPABASE_PUBLIC_KEY } from "./config.js";

const elements = {
  loadingView: document.querySelector("#loadingView"),
  configView: document.querySelector("#configView"),
  authView: document.querySelector("#authView"),
  welcomeView: document.querySelector("#welcomeView"),
  loginTab: document.querySelector("#loginTab"),
  registerTab: document.querySelector("#registerTab"),
  authForm: document.querySelector("#authForm"),
  nameGroup: document.querySelector("#nameGroup"),
  name: document.querySelector("#name"),
  email: document.querySelector("#email"),
  password: document.querySelector("#password"),
  formTitle: document.querySelector("#formTitle"),
  formDescription: document.querySelector("#formDescription"),
  submitButton: document.querySelector("#submitButton"),
  authMessage: document.querySelector("#authMessage"),
  userName: document.querySelector("#userName"),
  userEmail: document.querySelector("#userEmail"),
  phraseForm: document.querySelector("#phraseForm"),
  phrase: document.querySelector("#phrase"),
  savePhraseButton: document.querySelector("#savePhraseButton"),
  phraseMessage: document.querySelector("#phraseMessage"),
  savedPhraseBox: document.querySelector("#savedPhraseBox"),
  savedPhrase: document.querySelector("#savedPhrase"),
  savedAt: document.querySelector("#savedAt"),
  cloudStatus: document.querySelector("#cloudStatus"),
  charCounter: document.querySelector("#charCounter"),
  logoutButton: document.querySelector("#logoutButton"),
};

let mode = "login";
let supabase = null;
let currentUser = null;

function showOnly(view) {
  [elements.loadingView, elements.configView, elements.authView, elements.welcomeView]
    .forEach((item) => item.classList.add("hidden"));
  view.classList.remove("hidden");
}

function hasConfiguration() {
  return SUPABASE_URL.startsWith("https://")
    && !SUPABASE_URL.includes("PEGA_AQUI")
    && SUPABASE_PUBLIC_KEY.length > 20
    && !SUPABASE_PUBLIC_KEY.includes("PEGA_AQUI");
}

function setMode(nextMode) {
  mode = nextMode;
  const isRegister = mode === "register";

  elements.loginTab.classList.toggle("active", !isRegister);
  elements.registerTab.classList.toggle("active", isRegister);
  elements.nameGroup.classList.toggle("hidden", !isRegister);
  elements.name.required = isRegister;
  elements.password.autocomplete = isRegister ? "new-password" : "current-password";
  elements.formTitle.textContent = isRegister ? "Crea tu cuenta" : "Inicia sesión";
  elements.formDescription.textContent = isRegister
    ? "Este será tu usuario de Panorama Cloud."
    : "Usa el correo y la contraseña de tu cuenta.";
  elements.submitButton.textContent = isRegister ? "Crear cuenta" : "Ingresar";
  hideMessage(elements.authMessage);
}

function showMessage(target, text, type = "error") {
  target.textContent = text;
  target.className = `message ${type}`;
}

function hideMessage(target) {
  target.textContent = "";
  target.className = "message hidden";
}

function setAuthBusy(busy) {
  elements.submitButton.disabled = busy;
  elements.submitButton.textContent = busy
    ? "Procesando…"
    : mode === "register" ? "Crear cuenta" : "Ingresar";
}

function friendlyError(error) {
  const message = error?.message ?? "Ocurrió un error inesperado.";
  const translations = {
    "Invalid login credentials": "El correo o la contraseña no son correctos.",
    "User already registered": "Ya existe una cuenta con ese correo.",
    "Password should be at least 6 characters": "La contraseña debe tener al menos 6 caracteres.",
    "Email not confirmed": "Debes confirmar tu correo antes de ingresar.",
    'relation "public.user_phrases" does not exist':
      'Todavía falta ejecutar el archivo SQL_SETUP.sql en Supabase.',
  };
  return translations[message] ?? message;
}

function formatDate(dateText) {
  return new Intl.DateTimeFormat("es-UY", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(dateText));
}

function renderSavedPhrase(row) {
  if (!row?.phrase) {
    elements.savedPhraseBox.classList.add("hidden");
    return;
  }

  elements.savedPhrase.textContent = row.phrase;
  elements.savedAt.textContent = `Última actualización: ${formatDate(row.updated_at)}`;
  elements.savedPhraseBox.classList.remove("hidden");
}

async function loadPhrase() {
  elements.cloudStatus.textContent = "Consultando…";
  hideMessage(elements.phraseMessage);

  const { data, error } = await supabase
    .from("user_phrases")
    .select("phrase, updated_at")
    .eq("user_id", currentUser.id)
    .maybeSingle();

  if (error) {
    elements.cloudStatus.textContent = "Error";
    showMessage(elements.phraseMessage, friendlyError(error));
    return;
  }

  if (data) {
    elements.phrase.value = data.phrase;
    elements.charCounter.textContent = `${data.phrase.length} / 250`;
    renderSavedPhrase(data);
    elements.cloudStatus.textContent = "Dato recuperado";
  } else {
    elements.phrase.value = "";
    elements.charCounter.textContent = "0 / 250";
    renderSavedPhrase(null);
    elements.cloudStatus.textContent = "Sin frase todavía";
  }
}

async function showWelcome(user) {
  currentUser = user;

  const metadataName = user.user_metadata?.name?.trim();
  const emailName = user.email?.split("@")[0] ?? "usuario";

  elements.userName.textContent = metadataName || emailName;
  elements.userEmail.textContent = user.email ?? "";
  showOnly(elements.welcomeView);

  await loadPhrase();
}

async function initialize() {
  if (!hasConfiguration()) {
    showOnly(elements.configView);
    return;
  }

  supabase = createClient(SUPABASE_URL, SUPABASE_PUBLIC_KEY);

  const { data, error } = await supabase.auth.getSession();

  if (error) {
    showOnly(elements.authView);
    showMessage(elements.authMessage, friendlyError(error));
    return;
  }

  if (data.session?.user) {
    await showWelcome(data.session.user);
  } else {
    showOnly(elements.authView);
  }

  supabase.auth.onAuthStateChange((_event, session) => {
    if (!session?.user) {
      currentUser = null;
      showOnly(elements.authView);
    }
  });
}

elements.loginTab.addEventListener("click", () => setMode("login"));
elements.registerTab.addEventListener("click", () => setMode("register"));

elements.authForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  hideMessage(elements.authMessage);
  setAuthBusy(true);

  const email = elements.email.value.trim();
  const password = elements.password.value;

  try {
    if (mode === "register") {
      const name = elements.name.value.trim();

      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { name } },
      });

      if (error) throw error;

      if (data.session) {
        await showWelcome(data.user);
      } else {
        setMode("login");
        elements.email.value = email;
        showMessage(
          elements.authMessage,
          "Cuenta creada. Revisa tu correo para confirmar el registro.",
          "success"
        );
      }
    } else {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) throw error;
      await showWelcome(data.user);
    }
  } catch (error) {
    showMessage(elements.authMessage, friendlyError(error));
  } finally {
    setAuthBusy(false);
  }
});

elements.phrase.addEventListener("input", () => {
  elements.charCounter.textContent = `${elements.phrase.value.length} / 250`;
});

elements.phraseForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  hideMessage(elements.phraseMessage);

  const phrase = elements.phrase.value.trim();

  if (!phrase) {
    showMessage(elements.phraseMessage, "Escribe una frase antes de guardar.");
    return;
  }

  elements.savePhraseButton.disabled = true;
  elements.savePhraseButton.textContent = "Guardando…";
  elements.cloudStatus.textContent = "Enviando…";

  const record = {
    user_id: currentUser.id,
    phrase,
    updated_at: new Date().toISOString(),
  };

  const { data, error } = await supabase
    .from("user_phrases")
    .upsert(record, { onConflict: "user_id" })
    .select("phrase, updated_at")
    .single();

  elements.savePhraseButton.disabled = false;
  elements.savePhraseButton.textContent = "Guardar en la nube";

  if (error) {
    elements.cloudStatus.textContent = "Error";
    showMessage(elements.phraseMessage, friendlyError(error));
    return;
  }

  renderSavedPhrase(data);
  elements.cloudStatus.textContent = "Guardado";
  showMessage(
    elements.phraseMessage,
    "La frase quedó guardada en Supabase.",
    "success"
  );
});

elements.logoutButton.addEventListener("click", async () => {
  elements.logoutButton.disabled = true;
  const { error } = await supabase.auth.signOut();
  elements.logoutButton.disabled = false;

  if (error) {
    showMessage(elements.phraseMessage, friendlyError(error));
    return;
  }

  currentUser = null;
  elements.authForm.reset();
  elements.phrase.value = "";
  renderSavedPhrase(null);
  setMode("login");
  showOnly(elements.authView);
});

initialize();
