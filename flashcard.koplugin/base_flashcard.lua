local BaseFlashcard = {
    show_next_callback = nil, -- callback to show the next highlight
    document_path = nil, -- path to the document
    highlight_page = nil, -- page of the highlight (highlights are sortet by document.highlight[page][index])
    highlight_index = nil, -- index of the highlight (highlight are sorted by document.highlight[page][index])
}

function BaseFlashcard:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    if o.init then o:init() end
    return o
end

function BaseFlashcard:show()
    assert(nil, "NOT IMPLEMENTED: Subclasses of BaseFlashcard must implement the show function")
end

return BaseFlashcard
