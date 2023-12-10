local led = {}

--状态灯
local ledStatus= gpio.setup(12, 0, gpio.PULLUP)
--闪闪就行了
sys.taskInit(function()
    ledStatus(0)
end)

--当前状态
--1：5秒一闪，模组未响应
--2：2秒一闪，没卡
--3：1秒一闪，没联网
--4：一直亮，正常
led.status = 1
local st = {5000,2000,1000,1}
--事件灯
local ledDoing= gpio.setup(13, 0, gpio.PULLUP)
--闪闪就行了
sys.taskInit(function()
    while true do
        ledDoing(1)
        sys.wait(100)
        if st[led.status] > 0 then
            ledDoing(0)
            sys.wait(st[led.status])
        end
    end
end)

return led
