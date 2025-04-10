cask "convertfast" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256" # This will need to be updated with the actual SHA256 of the release

  url "https://github.com/YOUR_USERNAME/ConvertFast/releases/download/v#{version}/ConvertFast-#{version}.zip"
  name "ConvertFast"
  desc "Menu bar app for automatic media conversion using FFmpeg and cwebp"
  homepage "https://github.com/YOUR_USERNAME/ConvertFast"

  depends_on formula: "ffmpeg"
  depends_on formula: "webp"
  depends_on macos: ">= :monterey"

  app "ConvertFast.app"

  zap trash: [
    "~/Library/Application Support/ConvertFast",
    "~/Library/Preferences/com.YOUR_USERNAME.ConvertFast.plist",
  ]
end 