# ConvertFast

A macOS menu bar app that automatically converts media files using FFmpeg and cwebp.

## Features

- 🔄 Runs in the macOS menu bar
- 📁 Watches a selected folder for new files
- 🎯 Automatically converts files based on their extension
- ⚙️ Customizable conversion templates
- 🎬 Supports various media conversions:
  - MP3 size reduction
  - MP4 compression
  - MOV to MP4 conversion
  - MP4 to GIF conversion
  - Images to WebP format

## Installation

### Via Homebrew (Recommended)

```bash
brew tap madrzak/convertfast
brew install --cask convertfast
```

### Manual Installation

1. Download the latest release from the [releases page](https://github.com/YOUR_USERNAME/ConvertFast/releases)
2. Extract the ZIP file
3. Move `ConvertFast.app` to your Applications folder
4. Install dependencies:
   ```bash
   brew install ffmpeg webp
   ```

## Usage

1. Click the ConvertFast icon in the menu bar
2. Select "Enable Auto-Convert" to start monitoring
3. Choose a folder to watch using "Select Watch Folder..."
4. Add files to the watched folder to trigger automatic conversion

## Customizing Conversion Templates

Create a `conversion_templates.json` file in the app's Application Support directory:

```json
{
    "templates": [
        {
            "inputExtension": "mp4",
            "outputExtension": "mp4",
            "command": "ffmpeg -i $input -vcodec libx264 -crf 23 -preset fast $output",
            "deleteOriginal": true
        }
    ]
}
```

Available placeholders:
- `$input`: Path to the input file
- `$output`: Path to the output file

## Requirements

- macOS Monterey or later
- FFmpeg
- WebP tools

## License

MIT License 