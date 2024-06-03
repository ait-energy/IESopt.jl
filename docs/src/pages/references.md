# Overview

This maintains a list of publications (journals, conferences, ...) where IESopt was applied as part of the modeling
approach. Entries are in alphabetical order. If you want to contribute a new publication, please follow the instructions
in the [Contributing](#contributing) section.

## Publications

```@eval
using IESopt, Markdown
path = abspath(dirname(pathof(IESopt)), "..", "docs", "src", "pages", "references", "publications")

ref_str = ""
items = []
for file in readdir(path; join=true)
    endswith(file, ".md") || continue
    raw_content = read(file, String)
    
    fulltitle = ""
    header = ""
    content = ""
    for line in eachline(IOBuffer(raw_content))
        if startswith(line, "# ")
            fulltitle = line[3:end]
            if length(fulltitle) > 92
                header = "$(fulltitle[1:88]) ..."
            else
                header = fulltitle
            end
        else
            content = "$(content)\n$(line)"
        end
    end

    push!(items, """
    !!! details "$(header)"
        _**$(fulltitle)**_
        $(replace(content, "\n" => "\n    "))
    """)
end

Markdown.parse(join(items, "\n"))
```

## Projects

```@eval
using IESopt, Markdown
path = abspath(dirname(pathof(IESopt)), "..", "docs", "src", "pages", "references", "projects")

ref_str = ""
items = []
for file in readdir(path; join=true)
    endswith(file, ".md") || continue
    raw_content = read(file, String)
    
    fulltitle = ""
    header = ""
    content = ""
    for line in eachline(IOBuffer(raw_content))
        if startswith(line, "# ")
            fulltitle = line[3:end]
            if length(fulltitle) > 92
                header = "$(fulltitle[1:88]) ..."
            else
                header = fulltitle
            end
        else
            content = "$(content)\n$(line)"
        end
    end

    push!(items, """
    !!! details "$(header)"
        _**$(fulltitle)**_
        $(replace(content, "\n" => "\n    "))
    """)
end

Markdown.parse(join(items, "\n"))
```

## Contributing

To contribute a new reference, either

- fork the [IESopt](https://github.com/ait-energy/IESopt.jl) repository, and directly add to the above list, or
- open an issue with the reference details.

See the template below for the structure of a reference.

### Publication Template

Please stick to APA format here, and always include a link as badge (if possible a DOI, if not other links are okay
too).

```markdown
# Title of the Publication

[![CITATION](url-of-your-badge)](link-to-doi-or-pure-or-other)

> _**Abstract --**_ Put your abstract text here.

> _**Keywords --**_ Put some, Keywords, In this, List

!!! details "Expand: Show citation"
    > Add your (APA styled!) citation here

```

### Project Template

To be added.

### Creating citation badges

You can use [shields.io](https://shields.io/badges) to create badges, or use standardized ones that you already have
(e.g., from Zenodo), otherwhise stick to the ones provided below.

> **Pure:**
> _(publications.ait.ac.at)_
> ```markdown
> [![CITATION](https://img.shields.io/badge/PURE-publications.ait.ac.at-none?style=social)](ADDYOURLINKHERE)
> ```

> **DOI:**
> ```markdown
> [![CITATION](https://img.shields.io/badge/DOI-10.XXXX%2Fname.YYYY.ZZZZZZ-none?style=social)](https://doi.org/10.XXXX/name.YYYY.ZZZZZZ)
> ```
