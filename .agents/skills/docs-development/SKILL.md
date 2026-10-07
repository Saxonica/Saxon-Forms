---
name: docs-development
description: For the documentation of SaxonForms. Follow the outlined process for developing comprehensive documentation in DocBook XML format, including UML diagrams and validation against the w3c playwright test suite. Trigger when user asks to create or update documentation for SaxonForms, or when validating documentation against the outlined criteria.
---
# Documentation of SaxonForms

## Documentation development process

- Follow the Outline given below.
- Docs should be written in DocBook XML format. See https://www.docbook.org/ for more information.
- Level of detail should be sufficient for a developer with intermediate XSLT and JavaScript experience to understand the implementation of SaxonForms and how to use it in their own projects.
- Use ant4docbook
    - Use the copy included at `ant4docbook-0.10.0`
    - Provide a build script that can be run to generate the documentation from the DocBook XML source files. The build script should use ant4docbook to process the XML files and generate the output in a format suitable for publishing (e.g. HTML, PDF).
- UML Diagrams
    - Create plantUML diagrams for the architecture and design of SaxonForms. 
    - These diagrams should be included in the documentation to provide a visual representation of the system.
    - Diagram Types
        - Use use-case diagrams to illustrate the different use cases of SaxonForms and how they interact with the system.
        - Use package diagrams to show the organization of the codebase and the relationships between different packages (e.g. XSLT files).
        - Use sequence diagrams to illustrate the interactions between different components of SaxonForms
            - Level of detail should be sufficient to understand the flow of data and control through the system, but not so detailed as to be overwhelming. Focus on key interactions (e.g. templates/functions) and components  that are relevant to understanding the implementation.
        - Use class diagrams to show the structure of the codebase.
        - Use component diagrams to show the high-level architecture of SaxonForms and how different components interact with each other.
            - All other diagrams must be consistent with the component diagrams and the subsystems it enumerates.
            - Include one hop interactions with the HTML/DOM/JS as well, to show how SaxonForms interacts with the environment it operates in.
        - Do not use Activity diagrams, instead use BPMN 2.x diagrams to illustrate the workflow of the system.
        - Use any other UML 2.x diagrams as needed to illustrate the architecture and design of SaxonForms.    
    - Diagrams should clearly delineate interactions of SaxonForms (XSLT) with the HTML/DOM/JS.
    - Follow Scott Ambler's guidelines for UML diagrams: https://agilemodeling.com/style.htm
    - PlantUML
        - The flavor of plantuml must be exportable as XMI 2.x, so that it can be imported into a UML modeling tool (3DS MagicDraw) for further refinement and maintenance.
        - The flavor of plantuml must be compatible with ant4docbook's plantuml extension, so that the diagrams can be automatically generated and included in the documentation.
        - UML Diagrams must standalone and be included via XInclude in the DocBook XML.
- Validation
    - Use the w3c playwright test suite to determine conformance and to validate the documentation. For each chapter in the documentation, identify the relevant tests in the w3c playwright test suite that correspond to the topics covered in that chapter. Use these tests as a basis for validating the accuracy and completeness of the documentation.
    - The documentation must be valid DocBook XML. Use an XML schema validator (or tools within `ant4docbook`) to ensure that the documentation is well-formed and valid according to the DocBook schema.
    - All sequence diagrams must be validated against the interactions they illustrate, to ensure that they accurately represent the flow of data and control through the system. 
      - Construct a test suite that traces the interactions illustrated in the sequence diagrams, and ensure that the implementation of SaxonForms matches the interactions shown in the diagrams. The SaxonForms implementation must only be modified insofar as to add tracing required for validation. Follow `xslt-xpath` and `general-development` skills for any necessary code changes. 
- Validation checkpoints
    - For each chapter given in the outline, create a checkpoint in the documentation development process. At each checkpoint, validate the documentation for that chapter against the criteria given above (e.g. valid DocBook XML, accurate UML diagrams, etc.). This will help ensure that the documentation is of high quality and meets the needs of developers who will be using it to understand and use SaxonForms. Prompt the user to review the documentation for that chapter and provide feedback on its clarity, accuracy, and completeness. Address any issues found before proceeding to the next chapter.
    - After the documentation for each chapter has been validated, address any issues found and update the documentation accordingly.
    - After all chapters are complete, perform a final validation of the entire documentation to ensure that it is consistent and meets the criteria given above.
## Outline

The documentation of SaxonForms Implementation roughly follows the structure of the [XForms specification](https://www.w3.org/TR/xforms11), with additional sections for reusable components and accessibility. The goal is not to rehash the XForms specification, but to provide a clear mapping between the specification and the implementation of SaxonForms. As an implementation guide it will provide UML illustrate the the sturctural and behavioral aspects of the implementation.

- Introduction to SaxonForms
  - Overview
    - (Use the transcription of this video as a starting point for the overview section: https://www.youtube.com/watch?v=GWvl7EhsocI)
    - Use-cases    
- SaxonForms Implementation
  - SaxonForms and SaxonJS
  - Processing Model (Ch 4 of XForms specification)
    - Mapping XForms events to DOM events
  - Data Types (Ch 5 of XForms specification)
    - Support for XSD
  - Model Item Properties (Ch 6 of XForms specification)
    - Mapping XForms model item properties to internal state and DOM attributes
  - XPath and XForms (Ch 7 of XForms specification)
    - Mapping XForms XPath expressions to XPath 3.1+ expressions
  - Controls (Ch8, Ch9 of XForms specification)
    - Mapping XForms Controls to HTML Elements
    - Custom Controls
  - Actions (Ch10 of XForms specification)
    - Mapping XForms actions to XSLT functions
    - Mapping XForms actions to JavaScript functions
  - Submission (Ch 11 of XForms specification)
    - Mapping XForms submission to HTTP requests
  - Conformance
    - Conformance levels
    - Implementation dependant and implementation defined features
  - Additional Topics
    - Reusable Components
    - Accessibility
  - XSLT API reference