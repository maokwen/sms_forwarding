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
--3：快闪，没联网
--4：常亮，正常
led.status = 1
local st = {5000,2000,500,0}
--事件灯
local ledDoing= gpio.setup(13, 0, gpio.PULLUP)
--闪闪就行了
sys.taskInit(function()
    local prev = false
    while true do
        if st[led.status] > 0 then
            prev = false
            ledDoing(0)
            sys.wait(st[led.status])
            ledDoing(1)
        elseif prev == false then
            prev = true
            ledDoing(1)
        end
        sys.wait(100)
    end
end)

return led
