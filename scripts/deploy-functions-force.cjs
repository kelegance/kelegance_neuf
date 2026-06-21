/**
 * Active les APIs et accorde les rôles aux comptes de service par défaut GCP
 * pour débloquer le déploiement Cloud Functions.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");

const PROJECT_ID = "kelegance";
const PROJECT_NUMBER = "766009026310";
const COMPUTE_SA = `${PROJECT_NUMBER}-compute@developer.gserviceaccount.com`;
const CLOUDBUILD_SA = `${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com`;
const APPSPOT_SA = `${PROJECT_ID}@appspot.gserviceaccount.com`;

const ROLES = [
  "roles/storage.admin",
  "roles/storage.objectViewer",
  "roles/artifactregistry.writer",
  "roles/cloudbuild.builds.builder",
  "roles/logging.logWriter",
];

const RUNTIME_ROLES = [
  "roles/datastore.user",
  "roles/firebase.admin",
];

function getAccessToken() {
  const configPath = `${os.homedir()}/.config/configstore/firebase-tools.json`;
  const store = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const token = store.tokens?.access_token;
  if (!token) throw new Error("Pas de token Firebase — lancez firebase login");
  return token;
}

async function api(url, options = {}) {
  const token = getAccessToken();
  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  if (!res.ok) {
    const msg = body.error?.message || body.raw || res.statusText;
    throw new Error(`${res.status} ${url}: ${msg}`);
  }
  return body;
}

async function enableApi(service) {
  const url = `https://serviceusage.googleapis.com/v1/projects/${PROJECT_ID}/services/${service}:enable`;
  try {
    await api(url, { method: "POST", body: "{}" });
    console.log(`✓ API activée : ${service}`);
  } catch (err) {
    if (String(err.message).includes("already enabled") || String(err.message).includes("ALREADY_EXISTS")) {
      console.log(`• API déjà active : ${service}`);
    } else {
      console.warn(`! ${service}: ${err.message}`);
    }
  }
}

async function grantRoles(member, roles = ROLES) {
  const policy = await api(
    `https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}:getIamPolicy`,
    { method: "POST", body: JSON.stringify({}) },
  );

  const bindings = policy.bindings || [];
  for (const role of roles) {
    let binding = bindings.find((b) => b.role === role);
    if (!binding) {
      binding = { role, members: [] };
      bindings.push(binding);
    }
    const principal = `serviceAccount:${member}`;
    if (!binding.members.includes(principal)) {
      binding.members.push(principal);
      console.log(`✓ Rôle ${role} → ${member}`);
    }
  }

  await api(`https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}:setIamPolicy`, {
    method: "POST",
    body: JSON.stringify({ policy: { ...policy, bindings } }),
  });
}

async function main() {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

  console.log("Configuration GCP pour Cloud Functions…\n");

  const apis = [
    "compute.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
  ];

  for (const apiName of apis) {
    await enableApi(apiName);
  }

  console.log("\nAttribution des rôles IAM…\n");
  await grantRoles(COMPUTE_SA);
  await grantRoles(CLOUDBUILD_SA);
  await grantRoles(APPSPOT_SA, RUNTIME_ROLES);
  await grantRoles(COMPUTE_SA, RUNTIME_ROLES);

  console.log("\nLancement du déploiement Firebase Functions…\n");
  execSync("npm run deploy:functions -- --force", {
    cwd: path.join(__dirname, ".."),
    stdio: "inherit",
    env: { ...process.env, NODE_TLS_REJECT_UNAUTHORIZED: "0" },
  });
}

main().catch((err) => {
  console.error("\nÉchec :", err.message);
  process.exit(1);
});
