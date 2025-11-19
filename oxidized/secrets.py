import os
import sys
import hvac

# Vault path prefix - customize this for your environment
VAULT_PREFIX_PATH = "secret/oxidized/"

def vault_client() -> hvac.Client:
    """
    Returns a Vault client session used to retrieve secrets.  The client auth
    will be either a User's explicit token (dev-testing) or the Vault
    app-role-credentials when used in production deployment.
    """

    vault_addr, vault_token = os.environ["VAULT_ADDR"], os.getenv("VAULT_TOKEN")

    # if there is a local Vault token, then use it; this means that a Developer
    # is working on the app, and not a production run.

    if vault_token:
        return hvac.Client(url=vault_addr, token=vault_token)

    try:
        role_id = os.environ["VAULT_ROLE_ID"]
        secret_id = os.environ["VAULT_ROLE_SECRET"]

    except KeyError as exc:
        raise RuntimeError(f"Missing Vault production credentials: {str(exc)}")

    vault = hvac.Client()

    # TODO: check to see if there is an auth failure exception or return code
    #       that we need to check.
    vault.auth.approle.login(role_id=role_id, secret_id=secret_id)
    return vault

def fetch_secrets(vault_paths: dict) -> dict:
    """
    Retrieve secrets from Vault system.

    Parameters
    ----------
    vault_paths: dict
        key: str - the handle to the secrets, used by Caller
        value: str - the path to the secrets in the Vault system

    Returns
    -------
    dict:
        key: str - matches the key value in the vault_paths
        value: dict - the contents of the secret data.
    """
    vault = vault_client()
    secrets = dict()

    for key, path in vault_paths.items():
        res = vault.read(VAULT_PREFIX_PATH + path)
        try:
            secrets[key] = res["data"]
        except TypeError:
            raise RuntimeError(f"Unable to read vault path: {path}")

    return secrets

# Define the vault paths for secrets you need
# Customize this based on your Vault structure
vault_paths = {
    "netbox": "netbox",
    "netuser_rw": "network/read-write",
    "oxidized": "oxidized",
    # Add more paths as needed for your environment
}

def init_secrets():
    """Fetches secrets from Vault and loads them into environment variables."""
    keys_set = []
    secrets = fetch_secrets(vault_paths) 

    # Netbox - for device discovery
    netbox = secrets.get("netbox", {})
    os.environ.setdefault("NETBOX_TOKEN", netbox.get("token"))
    keys_set.append("NETBOX_TOKEN")
    os.environ.setdefault("NETBOX_ADDR", netbox.get("addr"))
    keys_set.append("NETBOX_ADDR")

    # Oxidized SSH keys - for Git operations
    oxidized = secrets.get("oxidized", {})
    os.environ["OXIDIZED_PRIVATE_KEY"] = oxidized.get("private_key")
    keys_set.append("OXIDIZED_PRIVATE_KEY")
    os.environ["OXIDIZED_PUBLIC_KEY"] = oxidized.get("public_key")
    keys_set.append("OXIDIZED_PUBLIC_KEY")

    # Network credentials - for device access
    netuser_rw = secrets.get("netuser_rw", {})
    os.environ["NETWORK_USERNAME_RW"] = netuser_rw.get("username")
    keys_set.append("NETWORK_USERNAME_RW")
    os.environ["NETWORK_PASSWORD_RW"] = netuser_rw.get("password")
    keys_set.append("NETWORK_PASSWORD_RW")

    # Optional: PAN-OS API credentials (if using Palo Alto devices)
    # panorama = secrets.get("panorama", {})
    # os.environ["PAN_API_USER_RO"] = panorama.get("PAN_API_USER_RO")
    # keys_set.append("PAN_API_USER_RO")
    # os.environ["PAN_API_PASS_RO"] = panorama.get("PAN_API_PASS_RO")
    # keys_set.append("PAN_API_PASS_RO")

    return keys_set

def print_secrets_for_eval(variable_keys):
    for key in sorted(variable_keys):
        value = os.environ.get(key)
        if value is not None:
            # This ensures any single quotes in the secret are
            # correctly escaped so the 'export' command doesn't break.
            escaped_value = value.replace("'", "'\\''")
            print(f"export {key}='{escaped_value}'")

if __name__ == "__main__":
    # Initialize secrets and get the list of keys
    set_variable_keys = init_secrets()
    print_secrets_for_eval(set_variable_keys)
