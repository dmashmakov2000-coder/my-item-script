script_properties('work-in-pause')

local samp = require('samp.events')
local effil = require('effil')
local inicfg = require('inicfg')
local ffi = require('ffi')
local SCRIPT_VERSION = "0.0.1" -- Текущая версия вашего скрипта

local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Предполагаем, что имя файла скрипта - Item.lua
local SCRIPT_CONFIG_NAME = 'Item'
local SCRIPT_CONFIG_FILENAME = SCRIPT_CONFIG_NAME .. '.ini'

-- Добавляем списки предметов из второго скрипта
local items = {
    1811,
    555,
    1425,
    522,
	4344,
	5991,
	1146,
	731,
	9726.,
}

local items_name = {
    [1811] = "Bitcoin (BTC)",
    [555] = "Бронзовая рулетка",
    [1425] = "Платиновая рулетка",
    [522] = "Семейный талон",
	[4344] = "Талон +1 EXP ",
	[5991] = "Грунт",
    [1146] = "Гражданский талон",
	[731] = "Аz-Coins",
	[9726] = "Лотерейный билет 2к26",
}

-- Функция для проверки наличия элемента в таблице
local function tableIncludes(self, value)
    for _, v in pairs(self) do
        if v == value then
            return true
        end
    end
    return false
end

local cfg = inicfg.load({
    config = {
        chat = '',
        token = '',
        itemAdding = false
    }
}, SCRIPT_CONFIG_NAME) -- Изменено на SCRIPT_CONFIG_NAME

local chat = imgui.new.char[128](tostring(cfg.config.chat))
local token = imgui.new.char[128](tostring(cfg.config.token))

local itemAdding = imgui.new.bool(cfg.config.itemAdding)

local window = imgui.new.bool(false)

function main()
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage('[telegram truck] {ffffff}Активация: /item', 0x3083ff)
    sampRegisterChatCommand('item', function() window[0] = not window[0] end)
    wait(-1)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
end)

local newFrame = imgui.OnFrame(
    function() return window[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 180
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('telegram truck', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
        if imgui.InputText(u8('ИД Чат'), chat, ffi.sizeof(chat), imgui.InputTextFlags.Password) then
            cfg.config.chat = ffi.string(chat)
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME) -- Изменено на SCRIPT_CONFIG_FILENAME
        end
        if imgui.InputText(u8('Токен'), token, ffi.sizeof(token), imgui.InputTextFlags.Password) then
            cfg.config.token = ffi.string(token)
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME) -- Изменено на SCRIPT_CONFIG_FILENAME
        end

        if imgui.Checkbox(u8('Добавление предмета'), itemAdding) then
            cfg.config.itemAdding = itemAdding[0]
            inicfg.save(cfg, SCRIPT_CONFIG_FILENAME) -- Изменено на SCRIPT_CONFIG_FILENAME
        end
        imgui.End()
    end
)

local effilTelegramSendMessage = effil.thread(function(text, chatID, token)
    local requests = require('requests')
    -- Используем url_encode для правильной передачи данных
    requests.post(('https://api.telegram.org/bot%s/sendMessage'):format(token), {
        params = {
            text = text,
            chat_id = chatID,
        }
    })
end)

-- Функция url_encode из второго скрипта
function url_encode(text)
    local text = string.gsub(text, "([^%w-_ %.~=])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return string.gsub(text, " ", "+")
end

function sendTelegramMessage(text)
    -- Проверяем, что чат ID и токен не пустые
    local chat_id_str = ffi.string(chat)
    local token_str = ffi.string(token)

    if chat_id_str == '' or token_str == '' then
        print('[telegram truck] Ошибка: ID чата или токен Telegram не установлены.')
        return
    end

    local text_to_send = text:gsub('{......}', '') -- Убираем цветовые коды, если они есть
    effilTelegramSendMessage(url_encode(u8(text_to_send)), chat_id_str, token_str)
end

function samp.onServerMessage(color, text)
    -- Проверяем, включено ли добавление предметов и совпадает ли сообщение
    if color == -65281 and text:find("^Вам был добавлен предмет .+%. Откройте инвентарь, используйте клавишу 'Y' или /invent$") and itemAdding[0] then
        -- Извлекаем ID предмета из сообщения
        local item_str = text:match("Вам был добавлен предмет (.+)%. Откройте инвентарь, используйте клавишу 'Y' или /invent")
        local itemId = tonumber(item_str:match(":item(%d+):")) -- Предполагаем формат ":item<ID>:"

        if itemId then
            if tableIncludes(items, itemId) then
                -- Если предмет есть в нашем списке
                sendTelegramMessage(items_name[itemId])
            else
                -- Если предмета нет в списке, отправляем его ID с просьбой добавить
                sendTelegramMessage("Получен неизвестный предмет. ID: " .. itemId .. ". Пожалуйста, добавьте его в список.")
            end
        else
            -- Если не удалось извлечь ID предмета (неожиданный формат сообщения)
            sendTelegramMessage("Не удалось распознать ID полученного предмета. Сообщение: " .. text)
        end
    end
end


-- ======================================================================
-- АВТООБНОВЛЕНИЕ
-- ======================================================================

local UPDATE_URL = "https://github.com/dmashmakov2000-coder/my-item-script/raw/refs/heads/main/Item.lua"
local current_version = SCRIPT_VERSION

-- Функция для получения текущей версии с GitHub
local function checkForUpdates()
    local requests = require('requests')
    local response, status, _ = requests.get(UPDATE_URL)

    if status == 200 then
        local remote_script_content = response
        local remote_version = remote_script_content:match('local SCRIPT_VERSION = "(.-)"')

        if remote_version and remote_version ~= current_version then
            sampAddChatMessage(string.format('[Item] {ffff00}Доступно обновление! {ffffff}Текущая версия: %s, Новая версия: %s', current_version, remote_version), 0xFFFFFF)
            return remote_script_content -- Возвращаем содержимое нового скрипта
        end
    else
        sampAddChatMessage(string.format('[Item] {ff0000}Ошибка при проверке обновлений. Код: %s', status), 0xFFFFFF)
    end
    return nil
end

-- Функция для скачивания и замены файла скрипта
local function downloadAndUpdate(new_script_content)
    local script_path = thisScript().path -- Более надежный способ получить путь к скрипту

    local file = io.open(script_path, "w")
    if file then
        file:write(new_script_content)
        file:close()
        sampAddChatMessage(string.format('[Item] {00ff00}Скрипт успешно обновлен до версии {ffffff}%s!{00ff00} Перезапустите игру или скрипт для применения изменений.', current_version), 0xFFFFFF)
        return true
    else
        sampAddChatMessage(string.format('[Item] {ff0000}Ошибка при записи нового файла скрипта: %s', script_path), 0xFFFFFF)
        return false
    end
end

-- Обработчик для команды /update
sampRegisterChatCommand('itemupdate', function()
    sampAddChatMessage(string.format('[Item] {ffffff}Проверка обновлений...'), 0xFFFFFF)
    local new_script_content = checkForUpdates()
    if new_script_content then
        downloadAndUpdate(new_script_content)
    else
        sampAddChatMessage(string.format('[Item] {00ff00}У вас установлена последняя версия ({ffffff}%s{00ff00}).', current_version), 0xFFFFFF)
    end
end)

-- Автоматическая проверка при запуске (опционально)
-- Если вы хотите автоматическую проверку, лучше использовать os.clock() и onFrame() или отдельный effil.thread
-- Пример с onFrame():
-- local check_update_timer = os.clock()
-- local CHECK_INTERVAL = 60 -- Проверять каждые 60 секунд

-- function onFrame()
--     if os.clock() - check_update_timer > CHECK_INTERVAL then
--         check_update_timer = os.clock() -- Сбрасываем таймер
--         local new_script_content = checkForUpdates()
--         if new_script_content then
--             sampAddChatMessage(string.format('[Item] {ffff00}Доступно обновление! Используйте команду /itemupdate для установки.'), 0xFFFFFF)
--         end
--     end
-- end

-- ======================================================================
-- КОНЕЦ АВТООБНОВЛЕНИЯ
-- ======================================================================

