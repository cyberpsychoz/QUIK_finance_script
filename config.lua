-- Файл config.lua с параметрами для основного скрипта lua

-- Номер счета
local account = "1234567890"

-- Клиентский код
local client_code = "ABCDEF"

-- Ставка налога в процентах
local tax_rate = 0.13

-- Ставка биржевых сборов в валюте счета за один контракт
local fee_rate = 0.01

-- Клавиша для фиксации позиций-сделок по счету
local close_key = "F12"

-- Пароль для фиксации позиций-сделок по счету
local password = "qwerty"

-- Положение и размер окна терминала Quik в пикселях
local window_xpos = 100
local window_ypos = 100
local window_width = 800
local window_height = 600

-- Возвращаем таблицу с параметрами
return {
  account = account,
  client_code = client_code,
  tax_rate = tax_rate,
  fee_rate = fee_rate,
  close_key = close_key,
  password = password,
  window_xpos = window_xpos,
  window_ypos = window_ypos,
  window_width = window_width,
  window_height = window_height
}
