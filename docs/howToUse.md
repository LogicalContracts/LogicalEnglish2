# How to use the Logical English 2 web application

The Logical English (LE) web application is a simple IDE designed for developing, testing, and debugging Logical English programs.

## Getting Started

1.  **Open the Editor:** Navigate to the editor URL (e.g., `http://localhost:3050/editor/`).
2.  **The Interface:**
    *   **Top:** Header with filename and module information.
    *   **Middle:** Monaco-based code editor with syntax highlighting and error reporting.
    *   **Bottom:** Multi-tab panel for Queries, Graphs, and the LE Assistant.

## File Operations

### Opening and Saving
*   **New File:** `File > New` clears the editor.
*   **Open Local File:** `File > Open...` allows you to load a `.le` file from your computer.
*   **Open from Server:** `File > Open copy from server...` provides a list of built-in examples (like `citizenship`).
*   **Save:** `File > Save` or `Save As...` allows you to save your work back to your local filesystem.

> **⚠️ Browser Compatibility:** Direct file saving (writing back to the same file) requires a modern browser that supports the *File System Access API* (e.g., Chrome, Edge). In other browsers (e.g., Safari, Firefox), the "Save" action will instead trigger a **Download** of the file.

### Saving via URL (Quick Save)
The editor automatically synchronizes the current code into the browser's URL using a `text` parameter. 
*   **To "Save" a state:** Simply copy the current URL from your browser's address bar.
*   **To "Load" a state:** Paste that URL into a new tab. This is useful for sharing snippets or bookmarking a specific version of your logic.

## Writing Logic and Issue Reporting

As you type, the editor performs real-time verification:
*   **Syntax Highlighting:** Keywords, variables, and templates are colored for readability.
*   **Error Reporting:** Red squiggly lines indicate syntax errors or missing templates.
*   **Quick Fixes:** Hover over an error to see suggested fixes (e.g., automatically adding a missing template).
*   **Status:** The "Query" button in the bottom panel is disabled if the document contains errors.

![Editor Selection](images/an_editor_selection.png)

## Running Queries

1.  **Load the Module:** The editor proactively loads your code onto the server. You can see the session ID in the top header.
2.  **Select Scenario:** In the **Query** tab, select a scenario defined in your code (e.g., `scenario(alice, ...)`). You can also select "Another..." to type custom facts.
3.  **Select Query:** Select a query defined in your code (e.g., `query(one, ...)`).
4.  **Execute:** Click the **Query** button.

## Explanations and Navigation

Once a query is executed:
*   **Answers:** A list of results appears in the left side of the bottom panel.
*   **Explanation Tree:** Clicking an answer displays a natural language justification tree on the right.
*   **Navigation to Source:** 
    *   Clicking any node in the explanation tree will automatically scroll the editor to the corresponding rule or fact in your source code.
    *   The selected range will be highlighted in the editor, allowing you to quickly verify the logic.

## Advanced Features

*   **Graph View:** The **Graph** tab visualizes the dependencies between your rules and templates.
*   **LE Assistant:** Use the **LE Assistant** tab to ask questions about your code or request help with drafting new rules.
*   **Debugger:** Right-click in the editor and select **See PROLOG** to view the translated logic, or use the **Trace** button in the Query tab for step-by-step execution.
