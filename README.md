# ArmFwVersioner

This library is designed to work seamlessly with STM32 and other Eclipse-based IDEs.  
Its primary purpose is to provide an automated **firmware versioning and binary renaming system**.  
During each build:

- The system checks the current Git repository state and determines the next version tag (Vxx.xx.xx) based on **semantic versioning** (major/minor/patch).
- It generates a `version.h` header file that contains the commit ID, commit date/time, and version components (major, minor, patch).
- After a successful build, the `.bin` file in the Debug folder is automatically renamed using the **board name** (from `board_name.h`) and the **Git version tag**, ensuring every build artifact is uniquely identifiable and traceable during development and deployment.

## Features

- **Automatic Binary Renaming** – Renames the `.bin` file in the Debug folder after each build, including board name and version information.
- **Semantic Versioning (Major / Minor / Patch)** – Automatically bumps the firmware version according to Git tags. If no tag exists, the system starts from `V01.00.00`.
- **Version Header Generation** – Produces a `version.h` file containing commit metadata (ID, date, time) and semantic version components (major, minor, patch).
- **Seamless Integration** – Designed to integrate easily with STM32CubeIDE or other Eclipse-based build systems.
- **Lightweight & Fast** – Adds versioning with minimal overhead to the build process.

## Prerequisites
Before using the ArmFwVersioner library, ensure the following requirements are met:

- **Git** – Required to retrieve commit information (commit ID, date, and tags) and to manage semantic version tags (Vxx.xx.xx).
- **Bash Shell** – The scripts are written in Bash and require a Unix-like environment (Linux, macOS, or Windows with WSL/MSYS).
- **STM32CubeIDE or Eclipse-based IDE** – The build environment should be STM32CubeIDE or any other Eclipse-based IDE that supports post-build steps.
- **arm-none-eabi Toolchain (optional)** – If ELF file inspection is needed, make sure the ARM GCC toolchain is available in your system's PATH.
- **Basic Git Setup** – Your project must be initialized as a Git repository with at least one commit.  
  Additionally, at least one version tag (or none, in which case the system will start from `V01.00.00`) is required for semantic versioning to work.

## Usage

**Order matters:**  
1) Run `gitvergen.sh` manually from a terminal **with a bump type** (`major|minor|patch`) to create/push the next Git version tag and generate `version.h`.  
2) Configure the IDE to produce a `.bin` artifact. 
3) Configure the board name header file. 
4) Add `fwrename.sh` as a **post‑build step** so the binary is renamed automatically on every build.

#### 1) Run `gitvergen.sh` with a bump type (one‑time per release)
Open a terminal inside your project root (STM32CubeIDE: *Terminal* view → New Terminal), then run:

```bash
# Examples (choose one)
./path/to/armfwversioner/gitvergen.sh major
./path/to/armfwversioner/gitvergen.sh minor
./path/to/armfwversioner/gitvergen.sh patch
```
What this does:
- Detects the default branch and latest semantic tag (Vxx.xx.xx).
- If no tag exists, starts at V01.00.00.
- Bumps according to the argument and creates/pushes the new tag to origin.
- Generates/updates version.h (commit id, date/time, and VERSION_MAJOR/MINOR/PATCH).

Run this step whenever you want to issue a new firmware version.
You don’t need to hook gitvergen.sh into post‑build—run it explicitly with the bump you want.

#### 2) Enable binary output in STM32CubeIDE (or Eclipse‑based IDE)
In your project:

1. Project → Properties
2. C/C++ Build → Settings → Tool Settings
3. Under MCU Post build outputs, enable Convert to binary file (this produces a .bin in Debug/).
(If your IDE flavor differs, enable the binary/objcopy step so a .bin is emitted to the build output folder.)

#### 3) Configure board_name.h
The active hardware board name is determined based on predefined macros in the board_name.h file.

- If you are working with a supported board, ensure the correct macro (e.g., FAN_CONTROLLER) is added to the compiler's preprocessor definitions.
**To add it in STM32CubeIDE (or Eclipse-based IDE):**

    1. Right-click on your project in the Project Explorer and select Properties.
    2. Navigate to C/C++ Build → Settings.
    3. Go to the Tool Settings tab.
    4. Under MCU GCC Compiler → Preprocessor, click Add.
    5.Enter the desired macro, for example:
        ```bash
        FAN_CONTROLLER
        ```

    6. Apply the changes and close the settings dialog.
- If your hardware is not listed in board_name.h:
    1. Open Config/board_name.h.
    2. Add a new #elif defined(...) entry for your hardware:
        ```bash
        #elif defined(MY_CUSTOM_DEVICE)
            #define BOARD_NAME_STR "MY_CUSTOM_BOARD"
        .....    
        .....

        #elif defined(MY_CUSTOM_DEVICE_VERSION)
            #define BOARD_VERSION_NAME_STR "MY_CUSTOM_BOARD_VERSION"
        ```
    3. Add MY_CUSTOM_BOARD to the preprocessor definitions following the same steps as above.

Once configured, the active macro ensures the correct board name is embedded in the ELF file, which will be used by the renaming script.

#### 4) Add fwrename.sh as a post‑build step
Still in Project → Properties:
1. Go to C/C++ Build → Settings → Build Steps.
2. In Post‑build steps, add:
```bash
./path/to/armfwversioner/fwrename.sh
```
Adjust the path to where the scripts live in your repository.
What this does:
- Reads the active board name (from your board_name.h macros).
- Reads the Git version from the generated version.h.
- Renames the produced .bin to:
```bash
# Examples (choose one)
<BOARD_NAME>_<BOARD_VERSION_NAME>_<GIT_VERSION>.bin
```

#### 5) Verify
- Confirm version.h contains the expected commit/version fields (GIT_COMMIT_ID, GIT_DATE, GIT_TIME, GIT_VERSION, and VERSION_MAJOR/MINOR/PATCH).
- After building, check Debug/ for the renamed .bin.

**Tip:** If you protect tags or use a non‑origin remote, update gitvergen.sh accordingly (e.g., remote name) or ensure your credentials allow pushing tags.

#### 6) Build the Project

- When you build your project, the scripts will generate a version.h file containing version information (commit ID, date, etc.).
- After a successful build, the .bin file in the Debug folder will be automatically renamed to:
```bash
<BOARD_NAME>_<BOARD_VERSION_NAME>_<GIT_VERSION>.bin
```
This ensures each build artifact has a unique and traceable name.

#### 7) Check Output

- Verify that version.h contains the expected commit metadata.

- Confirm that the .bin file in the Debug directory is renamed as per the board and version information.

## Example

#### 1) Running `gitvergen.sh` (before the build)
When you run the versioning script with a bump type, you will see output similar to this:

```bash
$ ./Libs/armfwversioner/gitvergen.sh patch
Selected bump type: patch
=== Default branch & latest tag check ===
Default branch : main
HEAD commit    : 6cae28d0ef6789d349dead5889ba959231601202
Latest tag     : V01.00.00
Tag commit     : 2555c91aaaa8210bc1141025d6296cf260355f63
Result         : ❌ HEAD is NOT at the latest tag.
Detail         : HEAD is 3 commit(s) ahead of 'V01.00.00'.
------------------------------------------
Selected bump  : patch
Previous tag   : V01.00.00
Next version   : V01.00.01
------------------------------------------
Created tag    : V01.00.01
Pushed tag     : V01.00.01 -> origin
Generated header: ./Libs/armfwversioner/version.h (GIT_VERSION=V01.00.01, 1.0.1)
```
#### 2) Building the project
After the tag is created, trigger a build in STM32CubeIDE.
During the build, the console will show output similar to:
```bash
NEW_BIN_FILE: ./FAN_CONTROLLER_V1_V01.00.00.bin
```
#### 3) After the build

- The Debug folder will contain a binary named: 
```bash
FAN_CONTROLLER_V1_V01.00.00.bin
```
- The version.h file will include metadata such as:
```bash
// Version derived from Git tag (e.g., V01.02.03)
__attribute__((used)) static const char* GIT_VERSION    = "V01.00.00";

// Semantic version components
__attribute__((used)) static const int   VERSION_MAJOR  = 1;
__attribute__((used)) static const int   VERSION_MINOR  = 0;
__attribute__((used)) static const int   VERSION_PATCH  = 0;

// Zero-padded string forms (useful for UI/build banners)
__attribute__((used)) static const char* VERSION_MAJOR_STR = "01";
__attribute__((used)) static const char* VERSION_MINOR_STR = "00";
__attribute__((used)) static const char* VERSION_PATCH_STR = "00";
```
## Authors

**İlyas Başaran** - *Creator and Maintainer*

## Contributing and Issue Tracker

Contributions are welcome! Feel free to submit issues or pull requests. If you encounter any problems or have suggestions for improvement, please create an issue in the tracker.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
