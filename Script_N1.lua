-- Конфигурационный файл с параметрами
local config = dofile("config.lua")

-- Функция для получения сводной статистики по счету
local function get_account_stats(account)
  -- Получаем баланс, средства, маржу и свободную маржу по счету
  local balance = getParamEx("ACCOUNTS", account, "BALANCE").param_value
  local funds = getParamEx("ACCOUNTS", account, "FIRMUSE").param_value
  local margin = getParamEx("ACCOUNTS", account, "MARGIN").param_value
  local free_margin = funds - margin

  -- Получаем прибыль-убыток по счету в моменте
  local pl = getParamEx("ACCOUNTS", account, "GO").param_value

  -- Получаем прибыль-убыток по счету за день, неделю и месяц
  local pl_day = getParamEx("ACCOUNTS", account, "PL_DAY").param_value
  local pl_week = getParamEx("ACCOUNTS", account, "PL_WEEK").param_value
  local pl_month = getParamEx("ACCOUNTS", account, "PL_MONTH").param_value

  -- Получаем расходы по счету по списанным комиссиям и налогам к уплате за весь период счета
  local commission = getParamEx("ACCOUNTS", account, "COMMISSION").param_value
  local tax = pl * config.tax_rate -- Налог рассчитываем как процент от прибыли

  -- Возвращаем таблицу со статистикой по счету
  return {
    balance = balance,
    funds = funds,
    margin = margin,
    free_margin = free_margin,
    pl = pl,
    pl_day = pl_day,
    pl_week = pl_week,
    pl_month = pl_month,
    commission = commission,
    tax = tax
  }
end

-- Функция для получения статистики по открытым сделкам
local function get_trades_stats(account)
  -- Создаем таблицу для хранения статистики по открытым сделкам
  local trades_stats = {}

  -- Получаем список всех открытых позиций по счету
  local trades = getDepoLimits(account)

  -- Для каждой открытой позиции получаем код инструмента, направление сделки, кол-во контрактов и маржу по позиции
  for i = 0, getNumberOf("depo_limits") - 1 do
    local trade = getItem("depo_limits", i)
    local sec_code = trade.sec_code -- Код инструмента
    local direction = trade.limit_kind == 0 and "Long" or "Short" -- Направление сделки
    local quantity = trade.currentbal -- Кол-во контрактов
    local margin = trade.awg_position_price * quantity -- Маржа по позиции

    -- Получаем текущую цену инструмента из стакана заявок
    local price = tonumber(getParamEx(trade.class_code, sec_code, "LAST").param_value)

    -- Рассчитываем эквити в динамике в % и цифрами в валюте счета
    local equity = direction == "Long" and price * quantity or -price * quantity -- Эквити по позиции
    local equity_percent = (equity - margin) / margin * 100 -- Эквити в процентах

    -- Рассчитываем биржевые сборы по позиции
    local fee = config.fee_rate * quantity -- Биржевые сборы

    -- Добавляем статистику по позиции в таблицу
    table.insert(trades_stats, {
      sec_code = sec_code,
      direction = direction,
      quantity = quantity,
      margin = margin,
      equity = equity,
      equity_percent = equity_percent,
      fee = fee
    })
  end

  -- Возвращаем таблицу со статистикой по открытым сделкам
  return trades_stats
end

-- Функция для вывода статистики в отдельном окне терминала Quik
local function show_stats(account)
  -- Создаем окно терминала Quik с заданными параметрами (размеры, заголовок и т.д.)
  local window_id =
    AllocTable() -- Выделяем память для окна терминала Quik
  AddColumn(window_id, 0, "Параметр", true, QTABLE_STRING_TYPE, 20) -- Добавляем колонку для параметров статистики по счету и сделкам
  AddColumn(window_id, 1, "Значение", true, QTABLE_STRING_TYPE, 20) -- Добавляем колонку для значений статистики по счету и сделкам

  CreateWindow(window_id) -- Создаем окно терминала Quik

  SetWindowCaption(window_id, "Статистика по счету") -- Устанавливаем заголовок окна терминала Quik

  SetWindowPos(window_id, config.window_xpos, config.window_ypos, config.window_width, config.window_height) -- Устанавливаем положение и размер окна терминала Quik

  SetTableNotificationCallback(window_id, OnClick) -- Устанавливаем функцию обратного вызова при клике на ячейку окна терминала Quik

  InsertRow(window_id, -1) -- Вставляем строку в конец таблицы окна терминала Quik

  SetCell(window_id, GetSize(window_id) - 1, 0, "Счет") -- Записываем значение "Счет" в ячейку таблицы окна терминала Quik

  SetCell(window_id, GetSize(window_id) - 1, 1, account) -- Записываем номер счета в ячейку таблицы окна терминала Quik
  
  -- Получаем статистику по счету
  local account_stats = get_account_stats(account)

  -- Для каждого параметра статистики по счету вставляем строку в таблицу окна терминала Quik и записываем его значение
  for key, value in pairs(account_stats) do
    InsertRow(window_id, -1) -- Вставляем строку в конец таблицы окна терминала Quik
    SetCell(window_id, GetSize(window_id) - 1, 0, key) -- Записываем название параметра в ячейку таблицы окна терминала Quik
    SetCell(window_id, GetSize(window_id) - 1, 1, tostring(value)) -- Записываем значение параметра в ячейку таблицы окна терминала Quik
  end

  -- Получаем статистику по открытым сделкам
  local trades_stats = get_trades_stats(account)

  -- Для каждой открытой сделки вставляем строку в таблицу окна терминала Quik и записываем ее статистику
  for i, trade_stat in ipairs(trades_stats) do
    InsertRow(window_id, -1) -- Вставляем строку в конец таблицы окна терминала Quik
    SetCell(window_id, GetSize(window_id) - 1, 0, "Сделка №" .. i) -- Записываем номер сделки в ячейку таблицы окна терминала Quik

    -- Для каждого параметра статистики по сделке записываем его значение в ячейку таблицы окна терминала Quik
    for key, value in pairs(trade_stat) do
      InsertRow(window_id, -1) -- Вставляем строку в конец таблицы окна терминала Quik
      SetCell(window_id, GetSize(window_id) - 1, 0, key) -- Записываем название параметра в ячейку таблицы окна терминала Quik
      SetCell(window_id, GetSize(window_id) - 1, 1, tostring(value)) -- Записываем значение параметра в ячейку таблицы окна терминала Quik
    end

    InsertRow(window_id, -1) -- Вставляем пустую строку для разделения сделок
  end

  RedrawTable(window_id) -- Перерисовываем окно терминала Quik для отображения данных
end

-- Функция для закрытия всех открытых сделок по счету и фиксации результата
local function close_all_trades(account)
  -- Получаем список всех открытых позиций по счету
  local trades = getDepoLimits(account)

  -- Для каждой открытой позиции отправляем обратную заявку на закрытие по рынку
  for i = 0, getNumberOf("depo_limits") - 1 do
    local trade = getItem("depo_limits", i)
    local sec_code = trade.sec_code -- Код инструмента
    local class_code = trade.class_code -- Код класса инструмента
    local direction = trade.limit_kind == 0 and "S" or "B" -- Направление заявки на закрытие (противоположное направлению сделки)
    local quantity = trade.currentbal -- Кол-во контрактов для закрытия

    -- Создаем транзакцию для отправки заявки на закрытие по рынку
    local trans_id = tostring(os.time()) .. tostring(i) -- Уникальный идентификатор транзакции
    local transaction = {
      ["TRANS_ID"] = trans_id,
      ["ACTION"] = "NEW_ORDER",
      ["CLASSCODE"] = class_code,
      ["SECCODE"] = sec_code,
      ["OPERATION"] = direction,
      ["QUANTITY"] = quantity,
      ["TYPE"] = "M", -- Тип заявки - рыночная
      ["ACCOUNT"] = account,
      ["CLIENT_CODE"] = config.client_code
    }

    -- Отправляем транзакцию в торговую систему
    local res =
      sendTransaction(transaction) -- Возвращаемый результат - пустая строка в случае успеха или сообщение об ошибке в случае неудачи

    if res ~= "" then -- Если результат не пустой, значит произошла ошибка при отправке транзакции
      message("Ошибка при отправке заявки на закрытие по рынку: " .. res) -- Выводим сообщение об ошибке
      return false -- Прекращаем выполнение функции и возвращаем ложное значение
    end
end

  -- Возвращаем истинное значение, если все заявки на закрытие были успешно отправлены
  return true
end

-- Функция для отключения всех скриптов lua по инструментам
local function stop_all_scripts()
  -- Получаем список всех запущенных скриптов lua
  local scripts = getScriptPathList()

  -- Для каждого скрипта lua проверяем, является ли он скриптом по инструменту (содержит код инструмента в названии)
  for i = 0, getNumberOf("scripts_path") - 1 do
    local script = getItem("scripts_path", i)
    local script_name = script.path:match("[^/]+$") -- Извлекаем имя скрипта из полного пути
    local sec_code = script_name:match("%w+") -- Извлекаем код инструмента из имени скрипта

    -- Если код инструмента не пустой, значит это скрипт по инструменту
    if sec_code then
      -- Отправляем команду на остановку скрипта по инструменту
      local res = stopScript(sec_code)

      if res ~= "" then -- Если результат не пустой, значит произошла ошибка при остановке скрипта
        message("Ошибка при остановке скрипта по инструменту: " .. res) -- Выводим сообщение об ошибке
        return false -- Прекращаем выполнение функции и возвращаем ложное значение
      end
    end
  end

  -- Возвращаем истинное значение, если все скрипты по инструментам были успешно остановлены
  return true
end

-- Функция для обработки нажатия на клавишу для фиксации позиций-сделок по счету
local function OnKeyPress(key)
  -- Проверяем, является ли нажатая клавиша той, которая задана в конфигурационном файле для фиксации позиций-сделок по счету
  if key == config.close_key then
    -- Запрашиваем подтверждение вводом заданных в конфигурационном файле значений-пароля
    local password = requestString("Введите пароль для фиксации позиций-сделок по счету")

    -- Проверяем, совпадает ли введенный пароль с тем, который задан в конфигурационном файле
    if password == config.password then
      -- Закрываем все открытые сделки по счету и фиксируем результат
      local res1 = close_all_trades(config.account)

      if res1 then -- Если все сделки были успешно закрыты
        message("Все открытые сделки по счету " .. config.account .. " были закрыты и результат был зафиксирован") -- Выводим сообщение об успехе

        -- Отключаем все скрипты lua по инструментам
        local res2 = stop_all_scripts()

        if res2 then -- Если все скрипты были успешно отключены
          message("Все скрипты lua по инструментам были отключены") -- Выводим сообщение об успехе

          -- Завершаем работу основного скрипта lua
          message("Скрипт статистики по счету завершил работу") -- Выводим сообщение о завершении работы
          OnStop() -- Вызываем функцию для завершения работы скрипта lua
        else -- Если не все скрипты были успешно отключены
          message("Не удалось отключить все скрипты lua по инструментам. Пожалуйста, проверьте их состояние и отключите их вручную") -- Выводим сообщение об ошибке
        end
      else -- Если не все сделки были успешно закрыты
        message("Не удалось закрыть все открытые сделки по счету " .. config.account .. ". Пожалуйста, проверьте их состояние и закройте их вручную") -- Выводим сообщение об ошибке
      end
    else -- Если введенный пароль не совпадает с тем, который задан в конфигурационном файле
      message("Неверный пароль. Попробуйте еще раз") -- Выводим сообщение об ошибке
    end
  end
end

-- Функция для обработки клика на ячейку окна терминала Quik
local function OnClick(t_id, msg, par1, par2)
  -- Проверяем, является ли клик левой кнопкой мыши
  if msg == QTABLE_LBUTTONDBLCLK then
    -- Получаем значение ячейки, по которой кликнули
    local cell_value = GetCell(t_id, par1, par2).value

    -- Проверяем, является ли значение ячейки кодом инструмента
    if cell_value:match("%w+") then
      -- Запрашиваем подтверждение вводом заданных в конфигурационном файле значений-пароля
      local password = requestString("Введите пароль для закрытия сделки по инструменту " .. cell_value)

      -- Проверяем, совпадает ли введенный пароль с тем, который задан в конфигурационном файле
      if password == config.password then
        -- Закрываем сделку по инструменту и фиксируем результат
        local res = close_trade(config.account, cell_value)

        if res then -- Если сделка была успешно закрыта
          message("Сделка по инструменту " .. cell_value .. " была закрыта и результат был зафиксирован") -- Выводим сообщение об успехе

          -- Обновляем статистику в окне терминала Quik
          show_stats(config.account)
        else -- Если сделка не была успешно закрыта
          message("Не удалось закрыть сделку по инструменту " .. cell_value .. ". Пожалуйста, проверьте ее состояние и закройте ее вручную") -- Выводим сообщение об ошибке
        end
      else -- Если введенный пароль не совпадает с тем, который задан в конфигурационном файле
        message("Неверный пароль. Попробуйте еще раз") -- Выводим сообщение об ошибке
      end
    end
  end
end

-- Функция для завершения работы скрипта lua
local function OnStop()
  DestroyTable(window_id) -- Уничтожаем окно терминала Quik
  FreeTable(window_id) -- Освобождаем память от окна терминала Quik
end

-- Основная часть скрипта lua

-- Устанавливаем функцию обратного вызова при нажатии на клавишу для фиксации позиций-сделок по счету
setScriptPath(getScriptPath()) -- Устанавливаем путь к скрипту lua для корректной работы функции setKeyCallback()
setKeyCallback(config.close_key, OnKeyPress) -- Устанавливаем функцию OnKeyPress для обработки нажатия на клавишу config.close_key

-- Выводим статистику по счету и открытым сделкам в отдельном окне терминала Quik
show_stats(config.account)



  
