--[[--------------------------------------------------------------------
  SimpleInfoBar 1.0.0
  Компактная панель: местность, деньги, сумки, сеть, профессии, память.
  Клиент 1.12.1 / Lua 5.1 (Emberveil). Языки интерфейса: ru / en.
----------------------------------------------------------------------]]

local ADDON   = "SimpleInfoBar"
local VERSION = "1.0.0"

local FIRST_BAG, LAST_BAG = 0, 4      -- рюкзак + 4 экипированные сумки
local LOW_FREE, WARN_FREE = 3, 8      -- пороги подсветки

local COLOR_OK   = { 1.00, 1.00, 1.00 }
local COLOR_WARN = { 1.00, 0.82, 0.00 }
local COLOR_LOW  = { 1.00, 0.25, 0.25 }

local LABEL_COLOR = "|cff9d9d9d"      -- серый для подписей

local defaults = {
  point = "TOP", relPoint = "TOP", x = 0, y = -20,
  locked = false, hidden = false, background = false,
  labels = true, lang = "auto",
  showZone = true, showMoney = true, showBags = true,
  showNet = true, showProf = true, showMem = true,
  profBad = 10, profWarn = 25,   -- очков до потолка: красный / жёлтый
  order = "zone,money,bags,net,prof,mem",
}

----------------------------------------------------------------------
-- локализация
----------------------------------------------------------------------

local STRINGS = {
  ru = {
    money      = "Деньги",
    bags       = "Сумки",
    zone       = "Зона",
    net        = "Сеть",
    prof       = "Профессии",
    mem        = "Память",
    mNet       = "Сеть (FPS и задержка)",
    mProf      = "Профессии",
    mMem       = "Память аддонов",
    profSet    = "пороги профессий: красный < %d, жёлтый < %d",
    profErr    = "укажите число, например: /sib profwarn 25",
    tipFree    = "Свободно %d из %d слотов",
    tipLocked  = "Закреплена — /sib unlock",
    tipDrag    = "Тяните левой кнопкой мыши",
    shown      = "панель показана.",
    hidden     = "панель скрыта.",
    locked     = "панель закреплена, перетаскивание выключено.",
    unlocked   = "панель откреплена, можно тянуть левой кнопкой мыши.",
    bgOn       = "фон включён.",
    bgOff      = "фон выключен.",
    labelsOn   = "подписи включены.",
    labelsOff  = "подписи выключены.",
    langSet    = "язык: %s",
    reset      = "позиция сброшена.",
    posSet     = "позиция задана: %d вправо, %d вниз от верха экрана.",
    posErr     = "укажите два числа, например: /sib pos 0 -20",
    help       = "команды: /sib [menu | zone | money | bags | net | prof | mem | profwarn N | profbad N | show | hide | toggle | lock | unlock | bg | labels | lang ru/en/auto | pos X Y | reset | debug]",
    mLabels    = "Подписи",
    mShow      = "Показывать",
    mOrder     = "Порядок (клик — вверх)",
    mZone      = "Местность",
    mMoney     = "Деньги",
    mBags      = "Сумки",
    mBg        = "Фон панели",
    mLock      = "Закрепить",
    mLang      = "Язык",
    mAuto      = "Авто",
    mReset     = "Сбросить позицию",
    mHide      = "Скрыть панель",
    tipMenu    = "Правая кнопка — меню",
  },
  en = {
    money      = "Money",
    bags       = "Bags",
    zone       = "Zone",
    net        = "Net",
    prof       = "Professions",
    mem        = "Memory",
    mNet       = "Net (FPS and latency)",
    mProf      = "Professions",
    mMem       = "Addon memory",
    profSet    = "profession thresholds: red < %d, yellow < %d",
    profErr    = "give a number, for example: /sib profwarn 25",
    tipFree    = "%d of %d slots free",
    tipLocked  = "Locked — /sib unlock",
    tipDrag    = "Drag with the left mouse button",
    shown      = "panel shown.",
    hidden     = "panel hidden.",
    locked     = "panel locked, dragging disabled.",
    unlocked   = "panel unlocked, drag it with the left mouse button.",
    bgOn       = "background on.",
    bgOff      = "background off.",
    labelsOn   = "labels on.",
    labelsOff  = "labels off.",
    langSet    = "language: %s",
    reset      = "position reset.",
    posSet     = "position set: %d right, %d down from screen top.",
    posErr     = "give two numbers, for example: /sib pos 0 -20",
    help       = "commands: /sib [menu | zone | money | bags | net | prof | mem | profwarn N | profbad N | show | hide | toggle | lock | unlock | bg | labels | lang ru/en/auto | pos X Y | reset | debug]",
    mLabels    = "Labels",
    mShow      = "Show",
    mOrder     = "Order (click to move up)",
    mZone      = "Zone",
    mMoney     = "Money",
    mBags      = "Bags",
    mBg        = "Panel background",
    mLock      = "Lock in place",
    mLang      = "Language",
    mAuto      = "Auto",
    mReset     = "Reset position",
    mHide      = "Hide panel",
    tipMenu    = "Right click for the menu",
  },
}

local function CurrentLang()
  local pick = SimpleInfoBarDB and SimpleInfoBarDB.lang or "auto"
  if pick == "ru" or pick == "en" then return pick end
  local locale = GetLocale and GetLocale() or "enUS"
  if locale == "ruRU" then return "ru" end
  return "en"
end

local function L(key)
  return STRINGS[CurrentLang()][key] or key
end

----------------------------------------------------------------------
-- состояние
----------------------------------------------------------------------

local frame, text
local dirty, timer = true, 0
local freeSlots, totalSlots = 0, 0

local DEFAULT_ORDER = { "zone", "money", "bags", "net", "prof", "mem" }

-- порядок держим строкой в сохранениях: так он переживает любые правки таблиц
local function OrderList()
  local raw = SimpleInfoBarDB and SimpleInfoBarDB.order or "zone,money,bags,net,prof,mem"
  local list, n = {}, 0
  local rest = raw .. ","
  while true do
    local _, _, item, tail = string.find(rest, "^([^,]*),(.*)$")
    if not item then break end
    if item ~= "" then n = n + 1; list[n] = item end
    rest = tail
    if rest == "" then break end
  end
  -- страховка: добавляем всё, что потерялось
  local k = 1
  while DEFAULT_ORDER[k] do
    local found, j = false, 1
    while j <= n do
      if list[j] == DEFAULT_ORDER[k] then found = true end
      j = j + 1
    end
    if not found then n = n + 1; list[n] = DEFAULT_ORDER[k] end
    k = k + 1
  end
  return list, n
end

local function SaveOrder(list, n)
  local out, i = "", 1
  while i <= n do
    if i > 1 then out = out .. "," end
    out = out .. list[i]
    i = i + 1
  end
  SimpleInfoBarDB.order = out
end

-- поднять блок на одну позицию вверх
local function MoveUp(key)
  local list, n = OrderList()
  local i = 2
  while i <= n do
    if list[i] == key then
      list[i], list[i - 1] = list[i - 1], list[i]
      SaveOrder(list, n)
      return
    end
    i = i + 1
  end
end

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96" .. ADDON .. ":|r " .. msg)
  end
end

----------------------------------------------------------------------
-- данные
----------------------------------------------------------------------

-- медь -> "12g 34s 56c" с цветами
local function FormatMoney(copper)
  copper = copper or 0
  local g = math.floor(copper / 10000)
  local s = math.floor(copper / 100) - g * 100
  local c = copper - math.floor(copper / 100) * 100
  local out = ""
  if g > 0 then out = out .. "|cffffd700" .. g .. "g|r " end
  if g > 0 or s > 0 then out = out .. "|cffc7c7cf" .. s .. "s|r " end
  return out .. "|cffeda55f" .. c .. "c|r"
end

-- свободные и общие слоты в сумках 0-4
local function ScanBags()
  local free, total = 0, 0
  local bag = FIRST_BAG
  while bag <= LAST_BAG do
    local slots = GetContainerNumSlots(bag)
    if slots and slots > 0 then
      total = total + slots
      local slot = 1
      while slot <= slots do
        local texture = GetContainerItemInfo(bag, slot)
        -- пустой слот возвращает "" (в Lua это истина!), поэтому сравниваем явно
        if texture == nil or texture == "" then
          free = free + 1
        end
        slot = slot + 1
      end
    end
    bag = bag + 1
  end
  return free, total
end

----------------------------------------------------------------------
-- отрисовка
----------------------------------------------------------------------

local function Label(key)
  if not SimpleInfoBarDB.labels then return "" end
  return LABEL_COLOR .. L(key) .. "|r "
end

-- блок «местность»: зона и, если есть, подзона
local function SegZone()
  local zone = ""
  if GetZoneText then zone = GetZoneText() or "" end

  local sub = nil
  if GetSubZoneText then sub = GetSubZoneText() end
  -- GetSubZoneText не возвращает НИЧЕГО, когда подзоны нет (не пустую строку)
  if sub == nil then sub = "" end

  if zone == "" and sub == "" then return nil end
  if zone == "" then zone = sub; sub = "" end

  local out = Label("zone") .. "|cffffffff" .. zone .. "|r"
  if sub ~= "" and sub ~= zone then
    out = out .. " |cff9d9d9d· " .. sub .. "|r"
  end
  return out
end

local function SegMoney()
  return Label("money") .. FormatMoney(GetMoney())
end

local function SegBags(free, total)
  local color = COLOR_OK
  if free <= LOW_FREE then
    color = COLOR_LOW
  elseif free <= WARN_FREE then
    color = COLOR_WARN
  end
  return Label("bags") .. string.format("|cff%02x%02x%02x%d|r|cff808080/%d|r",
    math.floor(color[1] * 255), math.floor(color[2] * 255),
    math.floor(color[3] * 255), free, total)
end

-- зелёный -> жёлтый -> красный
local COLOR_GOOD = "|cff40ff40"
local COLOR_WARN = "|cffffd200"
local COLOR_BAD  = "|cffff4040"

local function Tint(value, good, warn, higherIsBetter)
  if higherIsBetter then
    if value >= good then return COLOR_GOOD end
    if value >= warn then return COLOR_WARN end
    return COLOR_BAD
  end
  if value <= good then return COLOR_GOOD end
  if value <= warn then return COLOR_WARN end
  return COLOR_BAD
end

-- FPS и задержка
local function SegNet()
  local fps = 0
  if GetFramerate then fps = GetFramerate() or 0 end
  fps = math.floor(fps + 0.5)

  local lag = 0
  if GetNetStats then
    -- этот клиент возвращает ТРИ значения: вход, исход, задержка
    local _, _, ms = GetNetStats()
    lag = ms or 0
  end
  lag = math.floor(lag + 0.5)

  return Label("net")
    .. Tint(fps, 50, 30, true) .. fps .. "|r|cff808080 fps|r"
    .. " |cff5a5a5a·|r "
    .. Tint(lag, 100, 250, false) .. lag .. "|r|cff808080 ms|r"
end

-- Известные вспомогательные профессии. Список нужен, только чтобы опознать
-- КАТЕГОРИЮ: достаточно одного совпадения, дальше берётся вся категория целиком.
-- Поэтому переименование отдельного навыка ничего не ломает.
local SECONDARY_HINTS = {
  ["Cooking"] = true, ["First Aid"] = true, ["Fishing"] = true,
  ["Кулинария"] = true, ["Первая помощь"] = true,
  ["Рыбная ловля"] = true, ["Рыболовство"] = true, ["Рыбалка"] = true,
}

-- Возвращает набор категорий, которые считаем профессиями:
--   основные  — в категории есть навык, который можно забыть (isAbandonable);
--   вспомогательные — в категории есть навык из списка выше.
-- Навыки оружия, языки, классовые умения и владение бронёй под эти признаки
-- не подходят и в панель не попадают.
local function ProfessionCategories()
  local cats = {}
  if not GetNumSkillLines or not GetSkillLineInfo then return cats end

  local total = GetNumSkillLines() or 0
  local current = nil
  local i = 1
  while i <= total do
    local name, header, _, _, _, _, maxRank, abandonable = GetSkillLineInfo(i)
    if header == 1 then
      current = name
    elseif current and name then
      if abandonable == 1 then
        cats[current] = true
      elseif SECONDARY_HINTS[name] and maxRank and maxRank > 1 then
        cats[current] = true
      end
    end
    i = i + 1
  end
  return cats
end

-- Цвет по остатку очков до потолка. Пороги абсолютные, а не в процентах:
-- блокирует именно потолок, и 30 очков до 225 так же срочно, как 30 до 75.
-- По умолчанию 10 и 25 — примерно седьмая часть и треть ступени в 75 очков.
local function ProfTint(rank, maxRank)
  local left = maxRank - rank
  local bad  = SimpleInfoBarDB.profBad  or 10
  local warn = SimpleInfoBarDB.profWarn or 25
  if left < bad then return COLOR_BAD end
  if left < warn then return COLOR_WARN end
  return "|cffffffff"
end

local function SegProf()
  if not GetNumSkillLines or not GetSkillLineInfo then return nil end

  local cats = ProfessionCategories()
  local total = GetNumSkillLines() or 0
  local out, count, current = "", 0, nil

  local i = 1
  while i <= total do
    local name, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)

    if header == 1 then
      current = name
    elseif name and maxRank and maxRank > 1 and current and cats[current] then
      if count > 0 then out = out .. " |cff5a5a5a·|r " end
      out = out .. "|cffd0d0d0" .. name .. "|r "
        .. ProfTint(rank, maxRank) .. rank .. "|r|cff808080/" .. maxRank .. "|r"
      count = count + 1
    end
    i = i + 1
  end

  if count == 0 then return nil end
  return Label("prof") .. out
end

-- Память скриптов. GetScriptMemory отдаёт целые мегабайты с округлением вниз,
-- поэтому при малом расходе берём точное значение у сборщика мусора.
local function SegMem()
  local mb = 0
  if GetScriptMemory then mb = GetScriptMemory() or 0 end

  if mb < 1 and collectgarbage then
    local kb = collectgarbage("count")
    if kb then mb = kb / 1024 end
  end

  local shown
  if mb < 10 then
    shown = string.format("%.1f", mb)
  else
    shown = string.format("%d", mb)
  end
  return Label("mem") .. "|cffffffff" .. shown .. "|r|cff808080 MB|r"
end

local function Refresh()
  if not frame or not frame:IsShown() then return end

  local free, total = ScanBags()
  freeSlots, totalSlots = free, total

  local list, n = OrderList()
  local out, shown = "", 0
  local i = 1
  while i <= n do
    local key = list[i]
    local seg = nil

    if key == "zone" and SimpleInfoBarDB.showZone then
      seg = SegZone()
    elseif key == "money" and SimpleInfoBarDB.showMoney then
      seg = SegMoney()
    elseif key == "bags" and SimpleInfoBarDB.showBags then
      seg = SegBags(free, total)
    elseif key == "net" and SimpleInfoBarDB.showNet then
      seg = SegNet()
    elseif key == "prof" and SimpleInfoBarDB.showProf then
      seg = SegProf()
    elseif key == "mem" and SimpleInfoBarDB.showMem then
      seg = SegMem()
    end

    if seg then
      if shown > 0 then out = out .. "  |cff5a5a5a|||r  " end
      out = out .. seg
      shown = shown + 1
    end
    i = i + 1
  end

  if shown == 0 then out = "|cff808080SimpleInfoBar|r" end

  text:SetText(out)
  frame:SetWidth(text:GetStringWidth() + 18)
end

local function UpdateBackdropAlpha(hover)
  if not frame then return end
  if SimpleInfoBarDB and SimpleInfoBarDB.background then
    frame:SetBackdropColor(0, 0, 0, 0.55)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
  elseif hover then
    frame:SetBackdropColor(0, 0, 0, 0.6)
    frame:SetBackdropBorderColor(1, 0.82, 0, 0.9)
  else
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
  end
end

local function ApplyPosition()
  local db = SimpleInfoBarDB
  frame:ClearAllPoints()
  frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

local function SavePosition()
  local point, _, relPoint, x, y = frame:GetPoint(1)
  if point then
    SimpleInfoBarDB.point    = point
    SimpleInfoBarDB.relPoint = relPoint or point
    SimpleInfoBarDB.x        = x or 0
    SimpleInfoBarDB.y        = y or 0
  end
end

----------------------------------------------------------------------
-- контекстное меню (правая кнопка)
----------------------------------------------------------------------

local menu, menuTitle
local menuButtons = {}
local hoverCount, menuIdle = 0, 0

local ITEM_H, TITLE_H, PAD = 18, 18, 8

local function EnterWidget() hoverCount = hoverCount + 1; menuIdle = 0 end
local function LeaveWidget() hoverCount = hoverCount - 1; if hoverCount < 0 then hoverCount = 0 end end

local function HideMenu()
  if menu then menu:Hide() end
end

-- описание пунктов строится заново при каждом открытии: подписи зависят от состояния
local function MenuItems()
  local items, count = {}, 0

  local function add(t)
    count = count + 1
    items[count] = t
  end

  add({ mark = "none", text = L("mShow") .. ":", header = true })

  add({ mark = "check", indent = true, on = SimpleInfoBarDB.showZone, text = L("mZone"), keep = true,
        action = function() SimpleInfoBarDB.showZone = not SimpleInfoBarDB.showZone; dirty = true end })
  add({ mark = "check", indent = true, on = SimpleInfoBarDB.showMoney, text = L("mMoney"), keep = true,
        action = function() SimpleInfoBarDB.showMoney = not SimpleInfoBarDB.showMoney; dirty = true end })
  add({ mark = "check", indent = true, on = SimpleInfoBarDB.showBags, text = L("mBags"), keep = true,
        action = function() SimpleInfoBarDB.showBags = not SimpleInfoBarDB.showBags; dirty = true end })
  add({ mark = "check", indent = true, on = SimpleInfoBarDB.showNet, text = L("mNet"), keep = true,
        action = function() SimpleInfoBarDB.showNet = not SimpleInfoBarDB.showNet; dirty = true end })
  add({ mark = "check", indent = true, on = SimpleInfoBarDB.showProf, text = L("mProf"), keep = true,
        action = function() SimpleInfoBarDB.showProf = not SimpleInfoBarDB.showProf; dirty = true end })
  add({ mark = "check", indent = true, on = SimpleInfoBarDB.showMem, text = L("mMem"), keep = true,
        action = function() SimpleInfoBarDB.showMem = not SimpleInfoBarDB.showMem; dirty = true end })

  add({ mark = "none", text = L("mOrder") .. ":", header = true })
  do
    local list, n = OrderList()
    local NAMES = { zone = "mZone", money = "mMoney", bags = "mBags",
                    net = "mNet", prof = "mProf", mem = "mMem" }
    local i = 1
    while i <= n do
      local key = list[i]
      local up = "   "
      if i > 1 then up = "|cffffd700^|r  " end
      add({ mark = "none", indent = true, text = up .. i .. ". " .. L(NAMES[key] or key), keep = true,
            action = function() MoveUp(key); dirty = true end })
      i = i + 1
    end
  end

  add({ mark = "check", on = SimpleInfoBarDB.labels, text = L("mLabels"), keep = true,
        action = function() SimpleInfoBarDB.labels = not SimpleInfoBarDB.labels; dirty = true end })

  add({ mark = "check", on = SimpleInfoBarDB.background, text = L("mBg"), keep = true,
        action = function()
          SimpleInfoBarDB.background = not SimpleInfoBarDB.background
          UpdateBackdropAlpha(false)
        end })

  add({ mark = "check", on = SimpleInfoBarDB.locked, text = L("mLock"), keep = true,
        action = function() SimpleInfoBarDB.locked = not SimpleInfoBarDB.locked end })

  add({ mark = "none", text = L("mLang") .. ":", header = true })

  add({ mark = "radio", on = (SimpleInfoBarDB.lang == "auto"), text = L("mAuto"), keep = true, indent = true,
        action = function() SimpleInfoBarDB.lang = "auto"; dirty = true end })
  add({ mark = "radio", on = (SimpleInfoBarDB.lang == "ru"), text = "Русский", keep = true, indent = true,
        action = function() SimpleInfoBarDB.lang = "ru"; dirty = true end })
  add({ mark = "radio", on = (SimpleInfoBarDB.lang == "en"), text = "English", keep = true, indent = true,
        action = function() SimpleInfoBarDB.lang = "en"; dirty = true end })

  add({ mark = "none", text = L("mReset"),
        action = function()
          SimpleInfoBarDB.point    = defaults.point
          SimpleInfoBarDB.relPoint = defaults.relPoint
          SimpleInfoBarDB.x        = defaults.x
          SimpleInfoBarDB.y        = defaults.y
          ApplyPosition()
        end })

  add({ mark = "none", text = L("mHide"),
        action = function()
          SimpleInfoBarDB.hidden = true
          frame:Hide()
        end })

  return items, count
end

local function ItemLabel(item)
  local prefix = ""
  if item.mark == "check" then
    prefix = item.on and "|cff40ff40[x]|r " or "|cff808080[  ]|r "
  elseif item.mark == "radio" then
    prefix = item.on and "|cff40ff40(*)|r " or "|cff808080( )|r "
  elseif item.indent then
    prefix = "     "
  end
  return prefix .. item.text
end

local function GetMenuButton(i)
  if menuButtons[i] then return menuButtons[i] end
  local b = CreateFrame("Button", "SimpleInfoBarMenuItem" .. i, menu)
  b:SetHeight(ITEM_H)
  b:SetFont("Fonts\\FRIZQT__.TTF", 12)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b:SetScript("OnEnter", EnterWidget)
  b:SetScript("OnLeave", LeaveWidget)
  menuButtons[i] = b
  return b
end

local function BuildMenu()
  if menu then return end

  menu = CreateFrame("Frame", "SimpleInfoBarMenu", UIParent)
  menu:SetFrameStrata("DIALOG")
  menu:SetToplevel(true)
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tileSize = 16, edgeSize = 14,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  menu:SetBackdropColor(0, 0, 0, 0.92)
  menu:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
  menu:SetScript("OnEnter", EnterWidget)
  menu:SetScript("OnLeave", LeaveWidget)
  menu:Hide()

  menuTitle = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not menuTitle:GetFont() or menuTitle:GetFont() == "" then
    menuTitle:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
  end
  menuTitle:SetJustifyH("LEFT")

  -- меню само закрывается, когда мышь ушла и с панели, и с него
  menu:SetScript("OnUpdate", function(self, elapsed)
    local e = elapsed or arg1 or 0
    if hoverCount > 0 then
      menuIdle = 0
    else
      menuIdle = menuIdle + e
      if menuIdle > 1.5 then HideMenu() end
    end
  end)
end

local function ShowMenu()
  BuildMenu()

  local items, n = MenuItems()
  menuTitle:SetText(ADDON .. "  |cff808080v" .. VERSION .. "|r")

  local width = menuTitle:GetStringWidth()
  local i = 1
  while i <= n do
    local b = GetMenuButton(i)
    b:SetText(ItemLabel(items[i]))
    if items[i].header then
      b:SetTextColor(1, 0.82, 0)
    else
      b:SetTextColor(1, 1, 1)
    end
    local w = b:GetTextWidth()
    if w > width then width = w end
    i = i + 1
  end
  width = width + PAD * 2 + 10

  local y = -(PAD + TITLE_H)
  menuTitle:ClearAllPoints()
  menuTitle:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD + 2, -PAD)

  i = 1
  while i <= n do
    local item = items[i]
    local b = GetMenuButton(i)
    b:SetWidth(width - PAD * 2)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, y)
    b:SetScript("OnClick", function()
      if item.header then return end
      item.action()
      if item.keep then
        ShowMenu()          -- перерисовать галочки
      else
        HideMenu()
      end
    end)
    b:Show()
    y = y - ITEM_H
    i = i + 1
  end

  -- лишние кнопки из прошлого показа прячем
  local j = n + 1
  while menuButtons[j] do
    menuButtons[j]:Hide()
    j = j + 1
  end

  menu:SetWidth(width)
  menu:SetHeight(PAD * 2 + TITLE_H + n * ITEM_H)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
  menu:Show()
  menuIdle = 0
end

local function ToggleMenu()
  if menu and menu:IsShown() then HideMenu() else ShowMenu() end
end

----------------------------------------------------------------------
-- создание панели
----------------------------------------------------------------------

local function BuildFrame()
  frame = CreateFrame("Frame", "SimpleInfoBarFrame", UIParent)
  frame:SetWidth(180)
  frame:SetHeight(22)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetPoint("TOP", UIParent, "TOP", 0, -20)

  frame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tileSize = 16, edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
  })

  text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not text:GetFont() or text:GetFont() == "" then
    text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
  end
  text:SetPoint("CENTER", frame, "CENTER", 0, 0)
  text:SetJustifyH("CENTER")
  text:SetText("...")

  local moving = false

  local function BeginMove()
    if SimpleInfoBarDB.locked or moving then return end
    moving = true
    frame:StartMoving()
  end

  local function EndMove()
    if not moving then return end
    moving = false
    frame:StopMovingOrSizing()
    SavePosition()
  end

  -- два пути захвата: RegisterForDrag (порог 15 px) и прямое нажатие мыши
  frame:SetScript("OnDragStart", BeginMove)
  frame:SetScript("OnDragStop",  EndMove)

  frame:SetScript("OnMouseDown", function(self, button)
    local btn = button or arg1
    if btn == "RightButton" then
      ToggleMenu()
    elseif btn == nil or btn == "LeftButton" then
      BeginMove()
    end
  end)

  frame:SetScript("OnMouseUp", function(self, button)
    EndMove()
  end)

  frame:SetScript("OnHide", EndMove)

  frame:SetScript("OnEnter", function()
    EnterWidget()
    UpdateBackdropAlpha(true)
    if GameTooltip then
      GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(ADDON)
      GameTooltip:AddLine(string.format(L("tipFree"), freeSlots, totalSlots), 1, 1, 1)
      if SimpleInfoBarDB.locked then
        GameTooltip:AddLine(L("tipLocked"), 1, 0.5, 0.5)
      else
        GameTooltip:AddLine(L("tipDrag"), 0.7, 0.7, 0.7)
      end
      GameTooltip:AddLine(L("tipMenu"), 0.7, 0.7, 0.7)
      GameTooltip:Show()
    end
  end)

  frame:SetScript("OnLeave", function()
    LeaveWidget()
    UpdateBackdropAlpha(false)
    if GameTooltip then GameTooltip:Hide() end
  end)

  -- страховочный опрос: имена событий клиента не документированы
  frame:SetScript("OnUpdate", function(self, elapsed)
    local e = elapsed or arg1 or 0
    timer = timer + e
    if timer >= 0.5 then
      timer = 0
      dirty = true
    end
    if dirty then
      dirty = false
      Refresh()
    end
  end)
end

----------------------------------------------------------------------
-- слэш-команды
----------------------------------------------------------------------

local function HandleSlash(msg)
  msg = string.lower(msg or "")
  msg = string.gsub(msg, "^%s+", "")
  msg = string.gsub(msg, "%s+$", "")

  if msg == "show" then
    SimpleInfoBarDB.hidden = false
    frame:Show()
    dirty = true
    Print(L("shown"))

  elseif msg == "hide" then
    SimpleInfoBarDB.hidden = true
    frame:Hide()
    Print(L("hidden"))

  elseif msg == "lock" then
    SimpleInfoBarDB.locked = true
    Print(L("locked"))

  elseif msg == "unlock" then
    SimpleInfoBarDB.locked = false
    Print(L("unlocked"))

  elseif msg == "zone" then
    SimpleInfoBarDB.showZone = not SimpleInfoBarDB.showZone
    dirty = true
    Print(L("mZone") .. ": " .. (SimpleInfoBarDB.showZone and "on" or "off"))

  elseif msg == "money" then
    SimpleInfoBarDB.showMoney = not SimpleInfoBarDB.showMoney
    dirty = true
    Print(L("mMoney") .. ": " .. (SimpleInfoBarDB.showMoney and "on" or "off"))

  elseif msg == "bags" then
    SimpleInfoBarDB.showBags = not SimpleInfoBarDB.showBags
    dirty = true
    Print(L("mBags") .. ": " .. (SimpleInfoBarDB.showBags and "on" or "off"))

  elseif msg == "net" then
    SimpleInfoBarDB.showNet = not SimpleInfoBarDB.showNet
    dirty = true
    Print(L("mNet") .. ": " .. (SimpleInfoBarDB.showNet and "on" or "off"))

  elseif msg == "prof" then
    SimpleInfoBarDB.showProf = not SimpleInfoBarDB.showProf
    dirty = true
    Print(L("mProf") .. ": " .. (SimpleInfoBarDB.showProf and "on" or "off"))

  elseif msg == "mem" then
    SimpleInfoBarDB.showMem = not SimpleInfoBarDB.showMem
    dirty = true
    Print(L("mMem") .. ": " .. (SimpleInfoBarDB.showMem and "on" or "off"))

  elseif string.sub(msg, 1, 8) == "profwarn" or string.sub(msg, 1, 7) == "profbad" then
    local _, _, key, val = string.find(msg, "^(prof%a+)%s+(%d+)$")
    val = tonumber(val)
    if val and val >= 0 and val <= 300 then
      if key == "profbad" then SimpleInfoBarDB.profBad = val else SimpleInfoBarDB.profWarn = val end
      dirty = true
      Print(string.format(L("profSet"), SimpleInfoBarDB.profBad, SimpleInfoBarDB.profWarn))
    else
      Print(L("profErr"))
    end

  elseif msg == "bg" then
    SimpleInfoBarDB.background = not SimpleInfoBarDB.background
    UpdateBackdropAlpha(false)
    Print(SimpleInfoBarDB.background and L("bgOn") or L("bgOff"))

  elseif msg == "labels" then
    SimpleInfoBarDB.labels = not SimpleInfoBarDB.labels
    dirty = true
    Print(SimpleInfoBarDB.labels and L("labelsOn") or L("labelsOff"))

  elseif string.sub(msg, 1, 4) == "lang" then
    local _, _, which = string.find(msg, "^lang%s+(%a+)$")
    if which == "ru" or which == "en" or which == "auto" then
      SimpleInfoBarDB.lang = which
      dirty = true
      Print(string.format(L("langSet"), which .. " (" .. CurrentLang() .. ")"))
    else
      Print("lang: ru | en | auto")
    end

  elseif msg == "reset" then
    SimpleInfoBarDB.point    = defaults.point
    SimpleInfoBarDB.relPoint = defaults.relPoint
    SimpleInfoBarDB.x        = defaults.x
    SimpleInfoBarDB.y        = defaults.y
    ApplyPosition()
    Print(L("reset"))

  elseif string.sub(msg, 1, 3) == "pos" then
    local _, _, px, py = string.find(msg, "^pos%s+(-?%d+)%s+(-?%d+)$")
    if px and py then
      SimpleInfoBarDB.point    = "TOP"
      SimpleInfoBarDB.relPoint = "TOP"
      SimpleInfoBarDB.x        = tonumber(px)
      SimpleInfoBarDB.y        = tonumber(py)
      ApplyPosition()
      Print(string.format(L("posSet"), tonumber(px), tonumber(py)))
    else
      Print(L("posErr"))
    end

  elseif msg == "menu" then
    ToggleMenu()

  elseif msg == "debug" then
    Print("v" .. VERSION .. ", lang=" .. CurrentLang()
      .. " (" .. tostring(GetLocale and GetLocale()) .. ")")
    Print("shown=" .. tostring(frame:IsShown())
      .. ", mouse=" .. tostring(frame:IsMouseEnabled())
      .. ", movable=" .. tostring(frame:IsMovable())
      .. ", locked=" .. tostring(SimpleInfoBarDB.locked))
    local pt, _, rp, dx, dy = frame:GetPoint(1)
    Print("anchor=" .. tostring(pt) .. "/" .. tostring(rp)
      .. " x=" .. tostring(dx) .. " y=" .. tostring(dy)
      .. " size=" .. tostring(frame:GetWidth()) .. "x" .. tostring(frame:GetHeight()))

  elseif msg == "" or msg == "toggle" then
    if frame:IsShown() then
      SimpleInfoBarDB.hidden = true
      frame:Hide()
    else
      SimpleInfoBarDB.hidden = false
      frame:Show()
      dirty = true
    end

  else
    Print(L("help"))
  end
end

----------------------------------------------------------------------
-- события
----------------------------------------------------------------------

local function InitDB()
  if type(SimpleInfoBarDB) ~= "table" then SimpleInfoBarDB = {} end
  for k, v in pairs(defaults) do
    if SimpleInfoBarDB[k] == nil then SimpleInfoBarDB[k] = v end
  end
end

local function OnEvent(self, ev)
  ev = ev or event

  if ev == "VARIABLES_LOADED" or ev == "PLAYER_LOGIN" then
    InitDB()
    ApplyPosition()
    UpdateBackdropAlpha(false)
    if SimpleInfoBarDB.hidden then frame:Hide() else frame:Show() end
  end

  dirty = true
end

InitDB()
BuildFrame()

local loader = CreateFrame("Frame", "SimpleInfoBarLoader")
loader:SetScript("OnEvent", OnEvent)
loader:RegisterEvent("VARIABLES_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_MONEY")
loader:RegisterEvent("BAG_UPDATE")
loader:RegisterEvent("BAG_CLOSED")
loader:RegisterEvent("ITEM_LOCK_CHANGED")
loader:RegisterEvent("UNIT_INVENTORY_CHANGED")
loader:RegisterEvent("ZONE_CHANGED")
loader:RegisterEvent("ZONE_CHANGED_INDOORS")
loader:RegisterEvent("ZONE_CHANGED_NEW_AREA")
loader:RegisterEvent("MINIMAP_ZONE_CHANGED")
loader:RegisterEvent("SKILL_LINES_CHANGED")
loader:RegisterEvent("CHAT_MSG_SKILL")

SLASH_SIMPLEINFOBAR1 = "/simpleinfobar"
SLASH_SIMPLEINFOBAR2 = "/sib"
SlashCmdList["SIMPLEINFOBAR"] = HandleSlash
