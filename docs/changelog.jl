function create_changelog()
    PATH_ROOT = dirname(@__DIR__)
    PATH_DOCS = joinpath(PATH_ROOT, "docs")

    # Read the changelog file.
    changelog = read(joinpath(PATH_ROOT, "CHANGELOG.md"), String)

    # Write the changelog.
    open(joinpath(PATH_DOCS, "src", "pages", "changelog.md"), "w") do f
        write(f, changelog)
    end
end

create_changelog()
