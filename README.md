# Blogcard Extension For Quarto

`blogcard` shortcode makes easy to produce a card-like link.

## Installing

To use `blogcard` extension in your Quarto project, run this command in terminal at the project's working directory.
This will install the extension under the `_extensions` subdirectory.

```bash
quarto add t-arae/blogcard
```

and then, apply `blogcard` filter by adding this lines into your yaml header of `.qmd` file.

```yaml
filters:
  - blogcard
```

## Using

To make a card by `blogcard` shortcode, write shortcode directive like this.

```markdown
{{{< blogcard https://quarto.org >}}}
```

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).

