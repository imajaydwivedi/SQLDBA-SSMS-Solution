// Place your key bindings in this file to override the defaults
// https://code.visualstudio.com/docs/getstarted/keybindings#_when-clause-contexts
[
    { "key": "ctrl+e",          "command": "extension.runQuery",
                                "when": "editorTextFocus && editorLangId == 'sql'" 
    },
    { "key": "F5",              "command": "extension.runQuery",
                                "when": "editorTextFocus && editorLangId == 'sql'" 
    },
    {
        "key": "F5",            "command": "extension.runCurrentStatement",
                                "when": "editorHasSelection && editorLangId == 'sql'" 
    },
    {
        "key": "f8",            "command": "extension.cancelQuery",
                                "when": "editorLangId == 'sql'" 
    },
    {
        "key": "f5",            "command": "workbench.action.debug.run",
                                "when": "!inDebugMode && editorLangId == 'python'"
    },
    {
        "key": "ctrl+f5",
        "command": "-workbench.action.debug.run",
        "when": "!inDebugMode && editorLangId == 'python'"
    },
    {
        "key": "ctrl+f5",
        "command": "workbench.action.debug.start",
        "when": "!inDebugMode && editorLangId == 'python'"
    },
    {
        "key": "f5",
        "command": "-workbench.action.debug.start",
        "when": "!inDebugMode && editorLangId == 'python'"
    },
]