{
	programs.distrobox={
		enable = true;
		containers = {
			ubuntu = {
				image = "ubuntu:24.04";
				init_hooks = [
					"sudo apt-get update -y"
					"sudo apt-get install -y ca-certificates"
					"mkdir -p /usr/local/bin/"
					"export PATH=/usr/local/bin:$PATH"
					# "wget https://download.swift.org/swift-6.1.2-release/ubuntu2404-aarch64/swift-6.1.2-RELEASE/swift-6.1.2-RELEASE-ubuntu24.04-aarch64.tar.gz -o swift.tar.gz"
					# "wget https://github.com/neovim/neovim/releases/download/v0.11.2/nvim-linux-arm64.tar.gz -o nvim.tar.gz"
				];
			};
		};
	};
}
