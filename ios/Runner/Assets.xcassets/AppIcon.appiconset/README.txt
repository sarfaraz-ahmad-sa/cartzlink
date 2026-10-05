Cartzlink iOS App Icons

1. Extract this ZIP on your computer.
2. Open your GitHub repository and navigate to:
   ios/Runner/Assets.xcassets/AppIcon.appiconset/
3. Choose Add file > Upload files. Upload the 15 PNG files INSIDE the extracted AppIcon.appiconset folder.
   Keep the same filenames. Keep your existing Contents.json unchanged.
   Do not upload the ZIP, README, or a nested AppIcon.appiconset folder into this directory.
4. Commit the changes to the branch used by Codemagic.
5. Update the version line in pubspec.yaml to version: 1.0.0+6 if 5 is still your latest uploaded build.
   Use a build number greater than the latest uploaded build if another build was uploaded meanwhile.
6. Commit and start a new Codemagic iOS build.
7. After App Store Connect finishes processing the new build, select it for your submission.

The PNG files are square, RGB, and opaque, with the existing Flutter AppIcon filenames.
The supplied logo was used as the reference for a high-resolution master.
