--[[
    Library of Congress API Helper Module
    
    This module handles all API interactions with loc.gov

    Based on API code developed for FolkRAG: https://github.com/darkivist/FolkRAG/
]]

local json = require("json")
local ltn12 = require("ltn12")
local logger = require("logger")
local ffiutil = require("ffi/util")

local LocApi = {}

-- Configuration
LocApi.request_pause = 1  -- seconds between requests
LocApi.long_request_pause = 60  -- seconds for rate limiting

-- URL encode helper
function LocApi:urlEncode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])",
            function(c) return string.format("%%%02X", string.byte(c)) end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- Fetch data from API with retry logic
function LocApi:fetchApiData(url, params, attempt_num)
    attempt_num = attempt_num or 0
    
    -- Build URL with parameters
    -- Check if URL already has query string
    local separator = url:match("%?") and "&" or "?"
    local param_string = separator
    for key, value in pairs(params or {}) do
        param_string = param_string .. key .. "=" .. tostring(value) .. "&"
    end
    -- Remove trailing &
    param_string = param_string:gsub("&$", "")
    local full_url = url .. param_string
    
    -- Replace http with https
    full_url = full_url:gsub("^http:", "https:")
    
    logger.dbg("LOC API: Fetching", full_url)
    
    -- Make request
    local response_body = {}
    local request, code, response_headers, status_line
    
    if full_url:match("^https://") then
        local https = require("ssl.https")
        request, code, response_headers, status_line = https.request{
            url = full_url,
            method = "GET",
            headers = {
                ["User-Agent"] = "KOReader/LOC-Plugin",
                ["Accept"] = "application/json",
            },
            sink = ltn12.sink.table(response_body),
        }
    else
        local http = require("socket.http")
        request, code, response_headers, status_line = http.request{
            url = full_url,
            method = "GET",
            headers = {
                ["User-Agent"] = "KOReader/LOC-Plugin",
                ["Accept"] = "application/json",
            },
            sink = ltn12.sink.table(response_body),
        }
    end
    
    -- Handle response codes
    if code == 429 then
        -- Rate limited, wait and retry
        logger.warn("LOC API: Rate limited, waiting", self.long_request_pause, "seconds")
        ffiutil.sleep(self.long_request_pause)
        return self:fetchApiData(url, params, attempt_num + 1)
    elseif code >= 500 and code < 600 then
        -- Server error, retry with backoff
        if attempt_num < 5 then
            logger.warn("LOC API: Server error, attempt", attempt_num + 1)
            ffiutil.sleep(10)
        elseif attempt_num <= 15 then
            logger.warn("LOC API: Server error, longer wait, attempt", attempt_num + 1)
            ffiutil.sleep(60)
        else
            logger.err("LOC API: Too many server errors")
            return nil
        end
        return self:fetchApiData(url, params, attempt_num + 1)
    elseif code == 403 then
        logger.err("LOC API: Access forbidden (403)")
        return nil
    elseif code ~= 200 then
        logger.err("LOC API: Request failed with code", code)
        return nil
    end
    
    -- Parse JSON response
    local response_text = table.concat(response_body)
    
    -- Log first 500 characters
    logger.dbg("LOC API: Response preview:", response_text:sub(1, 500))
    logger.dbg("LOC API: Response length:", #response_text)
    
    if #response_text == 0 then
        logger.err("LOC API: Empty response body")
        return nil
    end
    
    local ok, data = pcall(json.decode, response_text)
    
    if not ok then
        logger.err("LOC API: Failed to parse JSON response")
        logger.err("LOC API: Parse error:", data)
        logger.err("LOC API: First 1000 chars:", response_text:sub(1, 1000))
        return nil
    end
    
    -- Check for 404
    if data.status and data.status == 404 then
        logger.info("LOC API: Resource not found (404 in JSON)")
        return nil
    end
    
    return data
end

-- Retrieve a single search page
function LocApi:retrieveSingleSearchPage(search_url, page_num)
    page_num = page_num or 1
    
    local params = {
        fo = "json",
        at = "results,pagination",
        c = 100,  -- results per page
        sp = page_num,
    }
    
    local response = self:fetchApiData(search_url, params, 0)
    
    logger.dbg("LOC API: Response received:", response ~= nil)
    if response then
        logger.dbg("LOC API: Has results:", response.results ~= nil)
        if response.results then
            logger.dbg("LOC API: Number of results:", #response.results)
            
            -- Log first few URLs to see what we're getting
            for i = 1, math.min(3, #response.results) do
                if response.results[i].url then
                    logger.dbg("LOC API: Sample URL " .. i .. ":", response.results[i].url)
                end
                if response.results[i].title then
                    local title = response.results[i].title
                    if type(title) == "table" then
                        title = title[1] or "no title"
                    end
                    logger.dbg("LOC API: Sample title " .. i .. ":", title)
                end
            end
        end
    end
    
    if not response or not response.results then
        logger.warn("LOC API: No response or no results field")
        return {}
    end
    
    -- Filter to only items with /item/ URLs (these are actual items we can download)
    local filtered_results = {}
    for _, result in ipairs(response.results) do
        if result.url and result.url:match("/item/") then
            table.insert(filtered_results, result)
        end
    end
    
    logger.info("LOC API: Filtered " .. #response.results .. " results down to " .. #filtered_results .. " items")
    
    return filtered_results
end

-- Retrieve search results with pagination
function LocApi:retrieveSearchResults(search_url, max_pages)
    max_pages = max_pages or 10  -- Limit to avoid excessive requests
    
    local all_results = {}
    local params = {
        fo = "json",
        at = "results,pagination",
        c = 100,  -- results per page
    }
    
    for page = 1, max_pages do
        params.sp = page
        
        local response = self:fetchApiData(search_url, params, 0)
        if not response or not response.results then
            break
        end
        
        -- Add results
        for _, result in ipairs(response.results) do
            table.insert(all_results, result)
        end
        
        -- Check if there are more pages
        if not response.pagination or page >= (response.pagination.total_pages or 1) then
            break
        end
        
        ffiutil.sleep(self.request_pause)
    end
    
    -- Filter to only items with /item/ URLs
    local filtered_results = {}
    for _, result in ipairs(all_results) do
        if result.url and result.url:match("/item/") then
            table.insert(filtered_results, result)
        end
    end
    
    return filtered_results
end

-- Extract file data from item record
function LocApi:extractFileData(item_record)
    local files = {}
    
    if not item_record or not item_record.resources then
        logger.warn("LOC API: No resources in item record")
        return files
    end
    
    local item_id = item_record.id
    
    logger.dbg("LOC API: Processing", #item_record.resources, "resources")
    
    for resource_num, resource in ipairs(item_record.resources) do
        if resource.files then
            logger.dbg("LOC API: Resource has", #resource.files, "file arrays")
            for files_array_num, files_array in ipairs(resource.files) do
                -- Now files_array is the actual array of file objects
                for segment_num, file in ipairs(files_array) do
                    logger.dbg("LOC API:   File mimetype:", file.mimetype, "url:", file.url)
                    table.insert(files, {
                        url = file.url,
                        mimetype = file.mimetype,
                        size = file.size,
                        id = item_id,
                        resource_num = resource_num,
                        segment_num = segment_num,
                    })
                end
            end
        end
        
        -- Check for direct EPUB link (some items have this field)
        if resource.epub_file then
            logger.dbg("LOC API: Found direct EPUB link")
            table.insert(files, {
                url = resource.epub_file,
                mimetype = "application/epub",
                id = item_id,
                resource_num = resource_num,
            })
        end
        
        -- Check for direct PDF links (sometimes PDFs are here instead of in files[])
        if resource.pdf_file then
            logger.dbg("LOC API: Found direct PDF link (pdf_file)")
            table.insert(files, {
                url = resource.pdf_file,
                mimetype = "application/pdf",
                id = item_id,
                resource_num = resource_num,
            })
        end
        
        if resource.pdf then
            logger.dbg("LOC API: Found direct PDF link (pdf)")
            table.insert(files, {
                url = resource.pdf,
                mimetype = "application/pdf",
                id = item_id,
                resource_num = resource_num,
            })
        end
    end
    
    logger.dbg("LOC API: Extracted", #files, "total files")
    
    return files
end

-- Filter files by mimetype
function LocApi:filterFilesByMimetype(files, mimetypes)
    if not mimetypes or #mimetypes == 0 then
        return files
    end
    
    local filtered = {}
    for _, file in ipairs(files) do
        for _, mimetype in ipairs(mimetypes) do
            if file.mimetype == mimetype then
                table.insert(filtered, file)
                break
            end
        end
    end
    
    return filtered
end

-- Get item details
function LocApi:getItemDetails(item_id)
    local params = {
        fo = "json",
        at = "item,resources",
    }
    
    return self:fetchApiData(item_id, params, 0)
end

return LocApi
