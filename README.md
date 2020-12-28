# HeckR_Replace

HeckR_Replace is a wrapper for AutoHotkey's hotstring functionality.

# Functionallity & Usage

In HeckR_Replace the hotstring (replaces from now on) are defined in configuration files, to make it wasier on the general user.
Generally the compiled version is recommended to be used, since that way AutoHotkey does not have to be installed.

## Configuration Files

In order to define replaces, they have to be defined in a configuration files.  \
The only mandatory one is `HeckR_Replace.ini`, which has to be located in the same folder as the main script / executable.

The configuration files are similar to [general configuration ini files](https://en.wikipedia.org/wiki/INI_file) regarding syntax and hierarchy (sections, key-value pairs, `;` for comments, `` ` `` for escaping, [\`s\`t\`n\`r] as special escapable whitespace characters).  \
However neither the sections, not the keys have to be unique, and additional rules apply to some sections where it's mentioned.  \
Also, the order of sections and keys are important, since the processing of the files are serial, and in case of nested configurations (see [Replace Configs](#replace-configs)) is basically a [depth first search](https://en.wikipedia.org/wiki/Depth-first_search)

### Example

There is an example of a configuration file named `HeckR_Replace_example.ini`, which contains the possible settings, and short explanation comments (after `;`s)  \
This ini file is located in the `Replace_Example` folder, along with a few additional configuration files, to make the concept of sub configuration files easier to understand

The example is fully functional, and it can be tried out, by copying the content of the `Replace_Example` folder into the root folder.  \
(Originally, there is nothing in the repo to overwrite when copying the example. However make sure to back up any user created configuration files before copying, to make sure nothing gets lost)

### Premade Replace Collection

Since originally I created this script for myself, I also created a nice collection of replaces along the way, which is also available at [HeckR_Replace_Collection](https://github.com/Heck-R/HeckR_Replace_Collection)

## Sections

The configuration files have a number of possible sections to be defined, but all of these sections, along all of their keys are optional to use.

All of the explicitely mentioned sections use automatic [trimming](#trimming)

### Config Settings

Section name: `config settings`

#### General Purpose

Contains settings about the parsing of the configuration files

#### Keys

- **trimReplaceKeys**: Trim the keys of the defined replaces
  - Possible values: `true` | `false`
  - Default: `true`
- **trimReplaceValues**: Trim the values of the defined replaces
  - Possible values: `true` | `false`
  - Default: `true`
- **relativePathRoot**: Any kind of [relative path](#relative-path) originates from this path. (Essentially the "working folder")
  - Possible values: [Full path](#full-path) | [Relative path](#relative-path) 
  - Default: The mandatory configuration file's folder

### Replace Settings

Section name: `replace settings`

#### General Purpose

Contains settings that modify the way the replaces function

#### Keys

- **modifiers**: Additional modifiers for the subsequent replaces
  - Possible values: See [AutoHotkey - Hotstring Options](https://www.autohotkey.com/docs/Hotstrings.htm#Options)
  - Default: Empty String
- **wrapper**:  Automatically adds the defined string to both sides of each subsequent replace key. (Basically it sets *wrapperLeft* and *wrapperRight*)  \
  E.g.: Setting this to `¤` makes replace a key `asd` to work as if it were `¤asd¤`
  - Possible values: Any String
  - Default: Empty String
- **wrapperLeft**: Same as *wrapper*, but only the left side
  - Possible values: Any String
  - Default: Empty String
- **wrapperRight**: Same as *wrapper*, but only the right side
  - Possible values: Any String
  - Default: Empty String
- **toggleAbleSections**: Make it possible to turn whole sections of replaces on/off with their names
  - Possible values: `true` | `false`
  - Default: `false`
- **enableToggleAbleSectionsOnStart**: Enable toggleable sections when the script starts
  - Possible values: `true` | `false`
  - Default: `false`
- **toggleWrapper**: Same as *wrapper* but for toggling sections
  - Possible values: Any String
  - Default: Empty String
- **toggleWrapperLeft**: Same as *wrapperLeft* but for toggling sections
  - Possible values: Any String
  - Default: Empty String
- **toggleWrapperRight**: Same as *wrapperRight* but for toggling sections
  - Possible values: Any String
  - Default: Empty String
- **alternativeSectionDisabler**: Disabling sections can be done with this as well if defined (no wrappers are applied on this)
  - Possible values: Any String
  - Default: Empty String

### Replace Configs

Section name: `replace configs`

#### General Purpose

Contains references to other configuration files.  \
These configuration files are processed in order, before the rest of the current one.

#### Keys

- **configFile**: A reference to another config file which will be processed as well.  \
  The referenced file does **not** inherit settings of the currently processed one.  \
  When using a relative path, `fileName` means both `fileName.ini` and `fileName\fileName.ini`
  - Possible values: [Full path](#full-path) | [Relative path](#relative-path)
- **subConfigFile**: Same as *configFile*, but the referenced file **will** inherit the settings of the currently processed one
  - Possible values: [Full path](#full-path) | [Relative path](#relative-path)


### Replace Definition Sections

Section name: Anything other than the ones mentioned above.

#### General Purpose

Contains the defined replaces.  \
These will be the available replaces to use after the start of the main script / executable.

The replaces are loaded on startup, so any change in the configuration files will only have effect after a restart of the script / program.

#### Keys & Values

Both the keys and the values are any desired unicode strings.  \
The key is replaced to the value, when the key is typed (with the modifiers / options taken into consideration).  \

For more information on the replaces as options, please see [AutoHotkey - Hotstrings](https://www.autohotkey.com/docs/Hotstrings.htm).  \
(For clarification: a hotstring is basically in the format of `:<modifiers>:<key>::<value>`)

# Notes

## Trimming

Trimming means to remove whitespaces from the sides of strings.  \
E.g.: "&emsp;&emsp;word&emsp;" -> "word"

## Full Path

The full path to a file or a folder

E.g: `C:\folder`

## Relative Path

A path that is expected to exist under a predefined "working folder"

E.g.: If the working folder is `C:\folder\relativeRootFolder`, a relative path like `folder\subFolder` would essentially mean `C:\folder\relativeRootFolder\folder\subFolder` (`.` (current folder) and `..` (parent folder) can be used)

E.g: `folder` | `folder\subfolder` | `..\folder`

# Responsibility

Only use or do anything at your own risk. I do not take responsibility for any damage which occours from using or following anything here in any way, shape or form

# Dependencies

If you wish to use / play around with the scripts instead of the built version, you need some dependencies  \
All of the dependencies can be found in the following repository: [HeckR_AUH-Lib](https://github.com/Heck-R/HeckR_AUH-Lib)

The dependencies should be placed anywhere where they can be imported using the angle bracket syntax (e.g.: `<modulname>`). One possibility is to put them directly inside a folder named `Lib` next to the main script (`HeckR_Replace.ahk`)

Some of these might be 3rd party scripts. The original authors and sources are linked in the repository provided above

- HeckerFunc

# Donate

I'm making tools like this in my free time, but since I don't have much of it, I can't give all of them the proper attention.

If you like this tool, you consider it useful or it made you life easier, please do not hesitate to thank/encourage me to continue working on it with any amount you see fit. (You know, buy me a cup of coffee / gallon of lemonade / 5-course gourmet dish / whatever you think I deserve 🙂)

<a href="https://www.paypal.com/paypalme/HeckR9000">
    <img 
        width="200px"
        src="https://gist.githubusercontent.com/Heck-R/20e9c45c2242467a028c107929187789/raw/cde2167d941416815d0e6f90638d85e2f289c988/donate.svg">
</a>
