{delib, ...}:
# The fleet's SSH keys, by what they're for. Hosts authorize these instead of
# hand-edited authorized_keys files.
delib.module {
  name = "sshKeys";

  options.sshKeys = with delib; {
    # Mars's own devices: ordinary, unrestricted logins. The Windows laptop
    # (mars@navis-win) has no agent key: agents elsewhere don't reach it.
    personal = readOnly (listOfOption str [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB7fPGt6KAzwOVQqOV0JT74unUXDbdQHvD3yufYyvLKW mars@navis-win"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBsHqYKt58eFcZo7UdPX45CaEhLeGge+cE1Gdt74IHSv MacBook"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL2vmQG3o3yMTXUbHYM7evCpUo/V+gK8Lofajt/hEjrB navis"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARRfEXoLrza1riqJJb0qFVYqOhNpXJEP9VI11K2RPJH marshall@navis"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLNLzoJDzuVhWZXuUO70Yj6bWg6t8kBFH0fWZIIwTC1w9w7Uv0ERuSBcp752fOpkm7fY5c2lyt12/ymEOParbhk= navis-tpm-polaris"
    ]);

    # Each host's agent key (~/.ssh/id_ed25519_fleet). On hosts with fleet's
    # sandbox, sessions with these run in it.
    agents = readOnly (attrsOfOption str {
      argo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINmHB1IqZ2XbtRnxyXL7uAnuFB1e8dhGhBlHTTFL0IKU fleet-builder";
      polaris = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEtGBP9oDI1KcX1ZPh/QL/7TJzykmRN4zB3KljtG8BP fleet-polaris";
      canis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICCjjPRNWczwWtChAMOGLYHKTRvmhw1pNvy29b36hifi fleet-canis";
      # The laptop's macOS install.
      vela = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJLJdiKCr/5zw4CRfii4c6qiNQ40dLIhJxdtYXXcSIFe fleet-vela";
    });

    # argo's T3 release channel, deploying releases to Polaris and canis.
    t3Deploy = readOnly (strOption "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKDUtTH6Q1dhBf6GgMZDPnFBzpeNcx+emd7BRRFYPGGF t3-channel-deploy@argo");
  };
}
