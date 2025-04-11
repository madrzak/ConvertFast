cask "convertfast" do
  version "1.0.0"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"

  url "https://github.com/madrzak/ConvertFast/releases/download/v#{version}/ConvertFast-#{version}.zip"
  name "ConvertFast"
  desc "Menu bar app for automatic media conversion using FFmpeg and cwebp"
  homepage "https://github.com/madrzak/ConvertFast"

  depends_on formula: "ffmpeg"
  depends_on formula: "webp"
  depends_on macos: ">= :monterey"

  app "ConvertFast.app"

  zap trash: [
    "~/Library/Application Support/ConvertFast",
    "~/Library/Preferences/com.madrzak.ConvertFast.plist",
  ]
end 