const owner = "Rana-X";
const repo = "focuslocker.app";
const releaseApi = `https://api.github.com/repos/${owner}/${repo}/releases`;

const downloadButton = document.getElementById("download-button");
const releaseVersion = document.getElementById("release-version");
const releaseFile = document.getElementById("release-file");
const releaseStatus = document.getElementById("release-status");

async function loadRelease() {
  try {
    const response = await fetch(releaseApi, {
      headers: {
        Accept: "application/vnd.github+json"
      }
    });

    if (!response.ok) {
      throw new Error(`GitHub returned ${response.status}`);
    }

    const releases = await response.json();
    const release = releases.find((item) => !item.draft);
    if (!release) {
      throw new Error("No public release found yet");
    }

    const macAsset = release.assets.find((asset) => asset.name.toLowerCase().includes("macos.zip"))
      || release.assets.find((asset) => asset.name.toLowerCase().endsWith(".zip"));

    releaseVersion.textContent = release.tag_name;
    releaseStatus.textContent = release.prerelease ? "Public test build" : "Production release";

    if (macAsset) {
      downloadButton.href = macAsset.browser_download_url;
      downloadButton.textContent = "Download for macOS";
      releaseFile.textContent = `${macAsset.name} · ${formatBytes(macAsset.size)}`;
    } else {
      releaseFile.textContent = "Release asset not uploaded yet";
      downloadButton.href = release.html_url;
      downloadButton.textContent = "Open release page";
    }
  } catch (error) {
    releaseVersion.textContent = "Unavailable";
    releaseFile.textContent = "Check the releases page directly";
    releaseStatus.textContent = "Could not load release data";
    downloadButton.href = `https://github.com/${owner}/${repo}/releases`;
    downloadButton.textContent = "Open release page";
    console.error(error);
  }
}

function formatBytes(bytes) {
  if (!bytes) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  return `${value.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
}

loadRelease();
