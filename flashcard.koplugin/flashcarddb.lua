local util = require("ffi/util")
local Parser = require("highlightparser")
local DataStorage = require("datastorage")
local json = require("json")
local logger = require("logger")

local FlashcardDB = {
    parsing = false,
    db_path = util.joinPath(DataStorage:getFullDataDir(), "flashcards.json"),
    parser = Parser:new()
}

function FlashcardDB:new()
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function FlashcardDB:getClippings()
    local clippings = self.parser:parseHistory()
    -- Clean empty clippings
    for title, booknotes in pairs(clippings) do
        if #booknotes == 0 then
            clippings[title] = nil
        end
    end

    logger.dbg("clippings: ", clippings)
    return clippings
end

function FlashcardDB:clearDB()
    local file = io.open(self.db_path, "w")
    file:close()
end

function FlashcardDB:updateDB(data)
    logger.dbg("db_path: ", self.db_path)
    local file = io.open(self.db_path, "w")
    data = json.encode(data)
    logger.dbg("Saving data: ", data)
    file:write(data)
    file:close()
end

function FlashcardDB:parseDBFile()
    local data = {}
    local file = io.open(self.db_path, "r")
    logger.dbg("Trying to read FlashcardDB: ", self.db_path)
    if file then
        local raw_data = file:read()
        logger.dbg("Raw data from FlashcardDB file: ", raw_data)
        if raw_data then
            local parsed_data = json.decode(raw_data)
            logger.dbg("Parsed data from FlashcardDB: ", parsed_data)
            if parsed_data then
                for time_str, highlight in pairs(parsed_data) do
                    table.insert(data, tonumber(time_str), highlight)
                end
            end
        end
        file:close()
    else
        logger.dbg("Failed to open FlashcardDB: ", self.db_path)
    end

    logger.dbg("Data from FlashcardDB: ", data)
    return data
end

function FlashcardDB:removeDeletedAndDuplicateItems(data, timestamps)
    local res_data = {}
    local flags = {}
    for time, clipping in pairs(data) do
        if timestamps[time] and not flags[time] then
            table.insert(res_data, time, clipping)
            flags[time] = true
        end
    end

    return res_data
end

function FlashcardDB:parseDB()
    self.parsing = true

    local clippings = self:getClippings()
    local data = self:parseDBFile()

    local timestamps = {}
    local time
    for _ignore0, booknotes in pairs(clippings) do
        for _ignore1, chapter in ipairs(booknotes) do
            for _ignore2, clipping in ipairs(chapter) do
                clipping.title = booknotes.title
                clipping.author = booknotes.author
                if clipping.sort == "highlight" then
                    time = clipping.time
                    timestamps[time] = 1

                    if not data[time] then
                        clipping.last_shown = 0
                        clipping.efactor = 2.5
                        clipping.interval = 0
                        clipping.n = 0
                        data[time] = clipping
                    end
                end
            end
        end
    end

    data = self:removeDeletedAndDuplicateItems(data, timestamps)
    logger.dbg("data: ", data)

    logger.info("Updating db from parseDB")
    self:updateDB(data)

    self.parsing = false

    return data
end

return FlashcardDB
