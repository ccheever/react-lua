x = "REACT_FRAGMENT_TYPE"
y = "REACT_FRAGMENT" .. "_TYPE"
z = "REACT_PROVIDER_TYPE"

q = 0xead0
r = 0xead0
s = 0xeace
t = 0xeacd

d = {}

function cmpStr(n)
    for _=1,n do
        local yes = x == y
        local no = x == z
        d.yes = yes
        d.no = no
    end
end

function cmpNum(n)
    for _=1,n do
        local yes = q == r
        local no = s == t
        d.yes = yes
        d.no = no
    end
end

return function(n)

    function time(f) 
        local start = os.clock()
        f(n)
        local finish = os.clock()
        return finish - start
    end

    print(time(cmpNum))
    print(time(cmpStr))
    
end
