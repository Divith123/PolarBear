//
//  TemplateCatalog+Markdown.swift
//  PolarBear
//

import Foundation

extension TemplateCatalog {
    /// The file created when a project is switched to Markdown and has no Markdown file yet.
    static let markdownStarter = """
    # Untitled

    Start writing. The preview on the right updates as you type.

    ## What you can use

    - **Bold**, *italic*, ~~strikethrough~~ and `inline code`
    - [Links](https://www.apple.com) and images: `![A caption](figure.png)`
    - Numbered and bulleted lists, task lists and block quotes
    - Tables, code blocks and horizontal rules

    1. Open the **Download** menu above the preview to save the document as Markdown or PDF.
    2. The same menu copies it as rich text, HTML or plain text.

    - [x] Switch the project to Markdown
    - [ ] Write something

    > A quote looks like this.

    | Feature | Supported |
    | ------- | :-------: |
    | Tables  | Yes |
    | Code    | Yes |

    ```swift
    let greeting = "Hello, PolarBear"
    print(greeting)
    ```
    """
}
