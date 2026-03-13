local function escape_html(text)
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    return text
end

function CodeBlock(el)
    for _, class_name in ipairs(el.classes) do
        if class_name == "mermaid" then
            return pandoc.RawBlock(
                "html",
                '<pre class="mermaid">' .. escape_html(el.text) .. "</pre>"
            )
        end
    end
end
