module 'aux.tabs.search'

local completion = require 'aux.util.completion'
local filter_util = require 'aux.util.filter'
local scan = require 'aux.core.scan'
local gui = require 'aux.gui'
local listing = require 'aux.gui.listing'
local auction_listing = require 'aux.gui.auction_listing'

local FILTER_SPACING = 28.5

frame = CreateFrame('Frame', nil, AuxFrame)
frame:SetAllPoints()
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.filter = gui.panel(frame)
frame.filter:SetAllPoints(AuxFrame.content)

frame.results = gui.panel(frame)
frame.results:SetAllPoints(AuxFrame.content)

frame.saved = CreateFrame('Frame', nil, frame)
frame.saved:SetAllPoints(AuxFrame.content)

frame.saved.favorite = gui.panel(frame.saved)
frame.saved.favorite:SetWidth(252)
frame.saved.favorite:SetPoint('TOP', 0, 0)
frame.saved.favorite:SetPoint('BOTTOM', 0, 0)

frame.saved.autobuy = gui.panel(frame.saved)
frame.saved.autobuy:SetPoint('TOPRIGHT', frame.saved.favorite, 'TOPLEFT', -2.5, 0)
frame.saved.autobuy:SetPoint('BOTTOMLEFT', 0, 0)

frame.saved.recent = gui.panel(frame.saved)
frame.saved.recent:SetPoint('TOPLEFT', frame.saved.favorite, 'TOPRIGHT', 2.5, 0)
frame.saved.recent:SetPoint('BOTTOMRIGHT', 0, 0)
do
    local btn = gui.button(frame, 25)
    btn:SetPoint('TOPLEFT', 5, -8)
    btn:SetWidth(30)
    btn:SetHeight(25)
    btn:SetText('<')
    btn:SetScript('OnClick', previous_search)
    previous_button = btn
end
do
    local btn = gui.button(frame, 25)
    btn:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
    btn:SetWidth(30)
    btn:SetHeight(25)
    btn:SetText('>')
    btn:SetScript('OnClick', next_search)
    next_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.small)
	btn:SetHeight(25)
	btn:SetWidth(60)
	btn:SetText(color.label.enabled'Range:')
	btn:SetScript('OnClick', function()
		update_real_time(true)
	end)
	range_button = btn
end
do
	local btn = gui.button(frame, gui.font_size.small)
	btn:SetHeight(25)
	btn:SetWidth(60)
	btn:Hide()
	btn:SetText(color.label.enabled'Real Time')
	btn:SetScript('OnClick', function()
		update_real_time(false)
	end)
	real_time_button = btn
end
do
	local function change()
		local page = tonumber(this:GetText())
		local valid_input = page and tostring(max(1, page)) or ''
		if this:GetText() ~= valid_input then
			this:SetText(valid_input)
		end
	end
	do
		local editbox = gui.editbox(range_button)
		editbox:SetPoint('LEFT', range_button, 'RIGHT', 4, 0)
		editbox:SetWidth(40)
		editbox:SetHeight(25)
		editbox:SetAlignment('CENTER')
		editbox:SetNumeric(true)
		editbox:SetScript('OnTabPressed', function()
            if not IsShiftKeyDown() then
                last_page_input:SetFocus()
            end
        end)
		editbox.enter = execute
		editbox.change = change
		local label = gui.label(editbox, gui.font_size.medium)
		label:SetPoint('LEFT', editbox, 'RIGHT', 0, 0)
		label:SetTextColor(color.label.enabled())
		label:SetText('-')
		first_page_input = editbox
	end
	do
		local editbox = gui.editbox(range_button)
		editbox:SetPoint('LEFT', first_page_input, 'RIGHT', 5.8, 0)
		editbox:SetWidth(40)
		editbox:SetHeight(25)
		editbox:SetAlignment('CENTER')
		editbox:SetNumeric(true)
		editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                first_page_input:SetFocus()
            else
                search_box:SetFocus()
            end
        end)
		editbox.enter = execute
		editbox.change = change
		last_page_input = editbox
	end
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetText('Search')
    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    btn:SetScript('OnClick', function()
        if arg1 == 'RightButton' then
            set_filter(current_search.filter_string)
        end
        execute()
    end)
    start_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('TOPRIGHT', -5, -8)
    btn:SetText('Pause')
    btn:SetScript('OnClick', function()
        scan.abort(search_scan_id)
    end)
    stop_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetHeight(25)
    btn:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
    btn:SetBackdropColor(color.state.enabled())
    btn:SetText('Resume')
    btn:SetScript('OnClick', function()
        execute(true)
    end)
    resume_button = btn
end
do
	local editbox = gui.editbox(frame)
	editbox:EnableMouse(1)
	editbox.formatter = function(str)
		local queries = filter_util.queries(str)
		return queries and join(map(copy(queries), function(query) return query.prettified end), ';') or color.red(str)
	end
	editbox.complete = completion.complete_filter
	editbox:SetHeight(25)
	editbox.char = function()
		this:complete()
	end
	editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            last_page_input:SetFocus()
        else
            this:HighlightText(0, 0)
        end
	end)
	editbox.enter = execute
	search_box = editbox
end
do
    gui.horizontal_line(frame, -40)
end
do
    local btn = gui.button(frame, gui.font_size.large)
    btn:SetPoint('BOTTOMLEFT', AuxFrame.content, 'TOPLEFT', 10, 8)
    btn:SetWidth(243)
    btn:SetHeight(22)
    btn:SetText('Search Results')
    btn:SetScript('OnClick', function() subtab = RESULTS end)
    search_results_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.large)
    btn:SetPoint('TOPLEFT', search_results_button, 'TOPRIGHT', 5, 0)
    btn:SetWidth(243)
    btn:SetHeight(22)
    btn:SetText('Saved Searches')
    btn:SetScript('OnClick', function() subtab = SAVED end)
    saved_searches_button = btn
end
do
    local btn = gui.button(frame, gui.font_size.large)
    btn:SetPoint('TOPLEFT', saved_searches_button, 'TOPRIGHT', 5, 0)
    btn:SetWidth(243)
    btn:SetHeight(22)
    btn:SetText('Filter Builder')
    btn:SetScript('OnClick', function() subtab = FILTER end)
    new_filter_button = btn
end
do
    local frame = CreateFrame('Frame', nil, frame)
    frame:SetWidth(265)
    frame:SetHeight(25)
    frame:SetPoint('TOPLEFT', AuxFrame.content, 'BOTTOMLEFT', 0, -6)
    status_bar_frame = frame
end
do
    local btn = gui.button(frame.results)
    btn:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
    btn:SetText('Bid')
    btn:Disable()
    bid_button = btn
end
do
    local btn = gui.button(frame.results)
    btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
    btn:SetText('Buyout')
    btn:Disable()
    buyout_button = btn
end
do
    local btn = gui.button(frame.results)
    btn:SetPoint('TOPLEFT', buyout_button, 'TOPRIGHT', 5, 0)
    btn:SetText('Clear')
    btn:SetScript('OnClick', function()
        while tremove(current_search.records) do end
        current_search.table:SetDatabase()
    end)
end
do
    local btn1 = gui.button(frame.saved)
    btn1:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
    btn1:SetText('Favorite')
    btn1:SetScript('OnClick', function()
        add_favorite(search_box:GetText())
    end)

	local btn2 = gui.button(frame.saved)
	btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
	btn2:SetText('Auto Buy')
	btn2:SetScript('OnClick', function()
		add_auto_buy(search_box:GetText())
		update_search_listings()
	end)
end
do
    local btn1 = gui.button(frame.filter)
    btn1:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
    btn1:SetText('Search')
    btn1:SetScript('OnClick', function()
	    export_filter_string()
        execute()
    end)

    local btn2 = gui.button(frame.filter)
    btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
    btn2:SetText('Export')
    btn2:SetScript('OnClick', export_filter_string)

    local btn3 = gui.button(frame.filter)
    btn3:SetPoint('LEFT', btn2, 'RIGHT', 5, 0)
    btn3:SetText('Import')
    btn3:SetScript('OnClick', import_filter_string)
end
do
    local editbox = gui.editbox(frame.filter)
    editbox.complete_item = completion.complete(function() return aux_auctionable_items end)
    editbox:SetPoint('TOPLEFT', 14, -FILTER_SPACING)
    editbox:SetWidth(260)
    editbox.char = function()
        if blizzard_query.exact then
            this:complete_item()
        end
    end
    editbox:SetScript('OnTabPressed', function()
	    if blizzard_query.exact then
		    return
	    end
        if IsShiftKeyDown() then
            max_level_input:SetFocus()
        else
            min_level_input:SetFocus()
        end
    end)
    editbox.change = update_form
    editbox.enter = papply(editbox.ClearFocus, editbox)
    local label = gui.label(editbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
    label:SetText('Name')
    name_input = editbox
end
do
    local checkbox = gui.checkbox(frame.filter)
    checkbox:SetPoint('TOPLEFT', name_input, 'TOPRIGHT', 16, 0)
    checkbox:SetScript('OnClick', update_form)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
    label:SetText('Exact')
    exact_checkbox = checkbox
end
do
    local editbox = gui.editbox(frame.filter)
    editbox:SetPoint('TOPLEFT', name_input, 'BOTTOMLEFT', 0, -FILTER_SPACING)
    editbox:SetWidth(125)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            name_input:SetFocus()
        else
            max_level_input:SetFocus()
        end
    end)
    editbox.enter = papply(editbox.ClearFocus, editbox)
    editbox.change = function()
	    local valid_level = valid_level(this:GetText())
	    if tostring(valid_level) ~= this:GetText() then
		    this:SetText(valid_level or '')
	    end
	    update_form()
    end
    local label = gui.label(editbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
    label:SetText('Level Range')
    min_level_input = editbox
end
do
    local editbox = gui.editbox(frame.filter)
    editbox:SetPoint('TOPLEFT', min_level_input, 'TOPRIGHT', 10, 0)
    editbox:SetWidth(125)
    editbox:SetAlignment('CENTER')
    editbox:SetNumeric(true)
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            min_level_input:SetFocus()
        else
            name_input:SetFocus()
        end
    end)
    editbox.enter = papply(editbox.ClearFocus, editbox)
    editbox.change = function()
	    local valid_level = valid_level(this:GetText())
	    if tostring(valid_level) ~= this:GetText() then
		    this:SetText(valid_level or '')
	    end
	    update_form()
    end
    local label = gui.label(editbox, gui.font_size.medium)
    label:SetPoint('RIGHT', editbox, 'LEFT', -3, 0)
    label:SetText('-')
    max_level_input = editbox
end
do
    local checkbox = gui.checkbox(frame.filter)
    checkbox:SetPoint('TOPLEFT', max_level_input, 'TOPRIGHT', 16, 0)
    checkbox:SetScript('OnClick', update_form)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
    label:SetText('Usable')
    usable_checkbox = checkbox
end
do
    local dropdown = gui.dropdown(frame.filter)
    class_dropdown = dropdown
    dropdown:SetPoint('TOPLEFT', min_level_input, 'BOTTOMLEFT', 0, 5 - FILTER_SPACING)
    dropdown:SetWidth(300)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
    label:SetText('Item Class')
    UIDropDownMenu_Initialize(dropdown, initialize_class_dropdown)
    dropdown:SetScript('OnShow', function()
        UIDropDownMenu_Initialize(this, initialize_class_dropdown)
    end)
end
do
    local dropdown = gui.dropdown(frame.filter)
    subclass_dropdown = dropdown
    dropdown:SetPoint('TOPLEFT', class_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
    dropdown:SetWidth(300)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
    label:SetText('Item Subclass')
    UIDropDownMenu_Initialize(dropdown, initialize_subclass_dropdown)
    dropdown:SetScript('OnShow', function()
        UIDropDownMenu_Initialize(this, initialize_subclass_dropdown)
    end)
end
do
    local dropdown = gui.dropdown(frame.filter)
    slot_dropdown = dropdown
    dropdown:SetPoint('TOPLEFT', subclass_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
    dropdown:SetWidth(300)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
    label:SetText('Item Slot')
    UIDropDownMenu_Initialize(dropdown, initialize_slot_dropdown)
    dropdown:SetScript('OnShow', function()
        UIDropDownMenu_Initialize(this, initialize_slot_dropdown)
    end)
end
do
    local dropdown = gui.dropdown(frame.filter)
    quality_dropdown = dropdown
    dropdown:SetPoint('TOPLEFT', slot_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
    dropdown:SetWidth(300)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
    label:SetText('Min Quality')
    UIDropDownMenu_Initialize(dropdown, initialize_quality_dropdown)
    dropdown:SetScript('OnShow', function()
        UIDropDownMenu_Initialize(this, initialize_quality_dropdown)
    end)
end
gui.vertical_line(frame.filter, 332)
do
    local dropdown = gui.dropdown(frame.filter)
    dropdown:SetPoint('TOPRIGHT', -174.5, -10)
    dropdown:SetWidth(150)
    UIDropDownMenu_Initialize(dropdown, initialize_filter_dropdown)
    dropdown:SetScript('OnShow', function()
        UIDropDownMenu_Initialize(this, initialize_filter_dropdown)
    end)
    _G[dropdown:GetName() .. 'Text']:Hide()
    local label = gui.label(dropdown, gui.font_size.medium)
    label:SetPoint('RIGHT', dropdown, 'LEFT', -15, 0)
    label:SetText('Post Filter')
    filter_dropdown = dropdown
end
do
	local input = gui.editbox(frame.filter)
	input:SetPoint('CENTER', filter_dropdown, 'CENTER', 0, 0)
	input:SetWidth(150)
	input:SetScript('OnTabPressed', function() filter_parameter_input:SetFocus() end)
	input.complete = completion.complete(function() return temp-A('and', 'or', 'not', unpack(keys(filter_util.filters))) end)
	input.char = function() this:complete() end
	input.change = function()
		local text = this:GetText()
		if filter_util.filters[text] and filter_util.filters[text].input_type ~= '' then
			local _, _, suggestions = filter_util.parse_filter_string(text .. '/')
			filter_parameter_input:SetNumeric(filter_util.filters[text].input_type == 'number')
			filter_parameter_input.complete = completion.complete(function() return suggestions or empty end)
			filter_parameter_input:Show()
		else
			filter_parameter_input:Hide()
		end
	end
	input.enter = function()
		if filter_parameter_input:IsVisible() then
			filter_parameter_input:SetFocus()
		else
			add_post_filter()
		end
	end
	filter_input = input
end
do
    local input = gui.editbox(frame.filter)
    input:SetPoint('LEFT', filter_dropdown, 'RIGHT', 10, 0)
    input:SetWidth(150)
    input:SetScript('OnTabPressed', function()
	    filter_input:SetFocus()
    end)
    input.char = function() this:complete() end
    input.enter = add_post_filter
    input:Hide()
    filter_parameter_input = input
end
do
    local scroll_frame = CreateFrame('ScrollFrame', nil, frame.filter)
    scroll_frame:SetWidth(395)
    scroll_frame:SetHeight(270)
    scroll_frame:SetPoint('TOPLEFT', 348.5, -50)
    scroll_frame:EnableMouse(true)
    scroll_frame:EnableMouseWheel(true)
    scroll_frame:SetScript('OnMouseWheel', function()
	    local child = this:GetScrollChild()
	    child:SetFont('p', [[Fonts\ARIALN.TTF]], bounded(11, 23, select(2, child:GetFont()) + arg1*2))
	    update_filter_display()
    end)
    scroll_frame:RegisterForDrag('LeftButton')
    scroll_frame:SetScript('OnDragStart', function()
	    this.x, this.y = GetCursorPosition()
	    this.x_offset, this.y_offset = this:GetHorizontalScroll(), this:GetVerticalScroll()
		this.x_extra, this.y_extra = 0, 0
	    this:SetScript('OnUpdate', function()
		    local x, y = GetCursorPosition()
		    local new_x_offset = this.x_offset + x - this.x
		    local new_y_offset = this.y_offset + y - this.y

		    set_filter_display_offset(new_x_offset - this.x_extra, new_y_offset - this.y_extra)

		    this.x_extra = max(this.x_extra, new_x_offset)
		    this.y_extra = min(this.y_extra, new_y_offset)
	    end)
    end)
    scroll_frame:SetScript('OnDragStop', function()
	    this:SetScript('OnUpdate', nil)
    end)
    gui.set_content_style(scroll_frame, -2, -2, -2, -2)
    local scroll_child = CreateFrame('SimpleHTML', nil, scroll_frame)
    scroll_frame:SetScrollChild(scroll_child)
    scroll_child:SetFont('p', [[Fonts\ARIALN.TTF]], 23)
    scroll_child:SetTextColor('p', color.label.enabled())
    scroll_child:SetWidth(1)
    scroll_child:SetHeight(1)
    scroll_child:SetScript('OnHyperlinkClick', data_link_click)
--	    scroll_child:SetHyperlinkFormat("format") TODO
    scroll_child.measure = scroll_child:CreateFontString()
    filter_display = scroll_child
end

status_bars = t
tables = t
for _ = 1, 5  do
    local status_bar = gui.status_bar(frame)
    status_bar:SetAllPoints(status_bar_frame)
    status_bar:Hide()
    tinsert(status_bars, status_bar)

    local table = auction_listing.CreateAuctionResultsTable(frame.results, auction_listing.search_config)
    table:SetHandler('OnCellClick', function(cell, button)
        if IsAltKeyDown() and current_search.table:GetSelection().record == cell.row.data.record then
            if button == 'LeftButton' and buyout_button:IsEnabled() then
                buyout_button:Click()
            elseif button == 'RightButton' and bid_button:IsEnabled() then
                bid_button:Click()
            end
        end
    end)
    table:SetHandler('OnSelectionChanged', function(rt, datum)
        if not datum then return end
        find_auction(datum.record)
    end)
    table:Hide()
    tinsert(tables, table)
end

auto_buy_listing = listing.CreateScrollingTable(frame.saved.autobuy)
auto_buy_listing:SetColInfo{{name='Auto Buy Filters', width=1}}
auto_buy_listing:EnableSorting(false)
auto_buy_listing:DisableSelection(true)
auto_buy_listing:SetHandler('OnClick', handlers.OnClick)
auto_buy_listing:SetHandler('OnEnter', handlers.OnEnter)
auto_buy_listing:SetHandler('OnLeave', handlers.OnLeave)

recent_searches_listing = listing.CreateScrollingTable(frame.saved.recent)
recent_searches_listing:SetColInfo{{name='Recent Searches', width=1}}
recent_searches_listing:EnableSorting(false)
recent_searches_listing:DisableSelection(true)
recent_searches_listing:SetHandler('OnClick', handlers.OnClick)
recent_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
recent_searches_listing:SetHandler('OnLeave', handlers.OnLeave)

favorite_searches_listing = listing.CreateScrollingTable(frame.saved.favorite)
favorite_searches_listing:SetColInfo{{name='Favorite Searches', width=1}}
favorite_searches_listing:EnableSorting(false)
favorite_searches_listing:DisableSelection(true)
favorite_searches_listing:SetHandler('OnClick', handlers.OnClick)
favorite_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
favorite_searches_listing:SetHandler('OnLeave', handlers.OnLeave)