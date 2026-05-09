# Blockly-based Editor for Logical English (LE)

***TODO: RFEFINE spec, more granular; not sure worth our while ;-)

This document describes the design and functionality of a Blockly-based visual editor for Logical English. The goal is to provide a user-friendly interface for constructing LE programs using drag-and-drop blocks, which are then translated into standard LE text. This will be a web app accessing LE via (a possibly extended) classic_web_api.pl

## 1. Core Concepts

The Blockly editor will represent the hierarchical structure of an LE document. Each major section of an LE file will correspond to a top-level block or a specific workspace configuration.

### 1.1 Sections as Containers
The primary sections of an LE program will be represented as container blocks:
- **Knowledge Base**: `the knowledge base [NAME] includes: [STATEMENTS]`
- **Scenario**: `scenario [NAME] is: [FACTS] [EXPECTATIONS]`
- **Query**: `query [NAME] is: [GOALS]`
- **Ontology**: `the ontology is: [TAXONOMY]`
- **Templates**: `the predicates are: [TEMPLATE_DEFINITIONS]`

## 2. Block Categories

### 2.1 Document Structure
- **LE Document**: A root block that can contain multiple sections (KB, Scenarios, Queries, etc.).
- **Section Blocks**: Individual blocks for Knowledge Base, Scenario, Query, Ontology, and Templates.

### 2.2 Templates and Custom Blocks
One of the most powerful features of LE is its natural language templates.
- **Template Definition Block**: Used in the "Templates" section to define a new pattern (e.g., `*a person* is a friend of *another person*`).
- **Dynamic Block Generation**: When a template is defined, the editor should ideally generate a corresponding block that matches the template's structure.
    - *Example*: Defining `*a person* is a friend of *another person*` creates a block with two inputs (for the variables) and the text "is a friend of" in between.
- **Meta-Templates**: Templates can include other sentences as arguments (e.g., `*a person* says that *a sentence*`).
    - In Blockly, this would be a block with a "statement" input that can accept any other predicate block.

### 2.3 Rules and Facts
- **Fact Block**: A simple statement block.
- **Rule Block**: A block with a "Head" input and a "Body" input, representing `Head if Body.`
- **Unless Block**: An extension to the rule block for `Head if Body unless Condition.`

### 2.4 Logic and Control Flow
- **And/Or**: Blocks to combine multiple conditions.
- **Negation**: `it is not the case that [CONDITION]`
- **Universal Quantification**: A multi-input block for:
  ```le
  for all cases in which [CONDITIONS]
  it is the case that [CONSEQUENCE]
  ```

### 2.5 Aggregates
- **Aggregate Block**: `[RESULT] is the [OP] of each [VAR] such that [GOAL]`
- Operators: `sum`, `count`, `average`, `min`, `max`.

### 2.6 Variables and Constants
- **Variable Block**: A block for explicit variables `*name*`.
- **Implicit Variable Block**: Options for `a [TYPE]`, `the [TYPE]`, `some [TYPE]`, `each [TYPE]`, `which [TYPE]`.
- **Special Variables**: `who`, `what`, `when`, `where`.
- **Constant Blocks**:
    - String: `"text"`
    - Number: `123`
    - Date: `YYYY-MM-DD` (with a date picker)

### 2.7 Arithmetic and Comparisons
- **Math Blocks**: Standard addition, subtraction, multiplication, division.
- **Comparison Blocks**: `=`, `>`, `<`, `>=`, `<=`, `!=`.
- **System Predicate Blocks**: `is equal to`, `is known`, `is in`, etc.

## 3. Type Safety and Validation
LE derives types from variable names in templates (e.g., `*a person*` implies type `person`).
- **Blockly Type Checks**: The generated blocks should use Blockly's type system to ensure that only compatible variables or constants are plugged into specific slots.
- **Ontology Integration**: If the ontology defines `a student is a person`, then a `student` block should be allowed where a `person` is expected.

## 4. Dynamic Toolbox
The toolbox should be divided into static categories (Logic, Math, Variables, Sections) and a **Dynamic Category** that populates with blocks derived from the templates defined in the current document.

## 5. Code Generation (LE Text)
The editor will implement a Blockly generator that traverses the block tree and produces valid LE syntax.
- Proper indentation must be maintained.
- Section headers and colons must be correctly placed.
- Variable asterisks and implicit variable keywords must be handled.

## 6. Integration with LE Engine
- **Validation**: As the user builds blocks, the editor can call the LE `verify/1` predicate (via the LE backend) to highlight logical errors or missing templates.
- **Round-trip Editing**: Ideally, the editor should support importing existing LE text and converting it into blocks (though this is a complex task).

## 7. User Interface Layout of the Blockly Editor
- **Left**: Blockly Toolbox.
- **Center**: Blockly Workspace.
- **Right**: Real-time LE Text Preview.
- **Top**: Toolbar with "Run Tests", "Export LE", "Load Example" buttons.

## 8. User Interface Layout (whole)
The Blockly editor page experience will be similar to the Monac editor: (Blockly) editor at the top, Query (including answers and explanation) and LE Assistant tabbed panels below, reused form the main text-nased (Monaco) editor.
The File Download/Save As.. menu will generate standard LE text (possibly with the help of the LE backend server) prior to letting the ser save it

## 9. Testing
ALL LE examples in examples/moreExamples must render in the new Blockly Editor, and saving them must produce an equivalent LE program in memory (if not in text)