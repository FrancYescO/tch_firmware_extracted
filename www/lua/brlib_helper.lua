local M = {}

--------------------------------------------------routed and briding function-------------------------------------------
function M.routed(wantemp, lantemp, lanstemp, serftemp, lanvlan, wanvlan, switchport, a, b)

	wannametemp = wantemp
	wanname = string.gsub(wannametemp, wanvlan, "")
	lanname = string.format("%s %s",lantemp,lanvlan)
	lans = string.format("%s %s",lanstemp,switchport)
	serfstemp = serftemp
	serfstempt = string.gsub(serfstemp, a,"")
	serfsw = string.gsub(serfstempt, b,"")
	return wanname, lanname, lans, serfsw
end

function M.briding(wantemp, lantemp, lanstemp, serftemp, lanvlan, wanvlan, switchport, a, b)
	
	wanname = string.format("%s %s",wantemp,wanvlan)
	 lannametemp = lantemp
	 lanname = string.gsub(lannametemp,lanvlan,"")
	 serfsw = string.format("%s %s",serftemp,switchport)
	 lanstemp = lanstemp
	 lanst = string.gsub(lanstemp, a,"")
	 lans = string.gsub(lanst, b,"")
	 return wanname, lanname, lans, serfsw
end

------------------------------------------copy a table------------------------------------------------------------------------
function M.copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

----------------------------------------sort a table and create "ausgabe"-----------------------------------------------------------------------

function M.sort(numbers, words)
	local n = M.copy(numbers)
	local tt = M.copy(words)
	local length = #words
	local k
	local l
	for i=#tt, 1, -1 do
		for j = 1, i-1, 1 do
			if n[j]>=n[i] then
				k = n[i]
				l = tt[i]
				n[i]=n[j]
				tt[i]=tt[j]
				n[j]=k
				tt[j]=l
			end
		end
	end
	a = string.format("%s", tt[1])
	for k = 2, length, 1 do
		a = a.." "..string.format("%s", tt[k])
	end
	return a
end

-------------------------------------------split a string------------------------------------------------------------------------------
function M.split(str, ang)
	local tab = {}
	for vari in string.gfind(str, ang) do
		table.insert(tab, vari)
	end
	return tab
end

------------------------------------------link tab entries with %* and spaces--------------------------------------------------------------------
function M.spacesw(x)
local tab = M.copy(x)

	for i = 1, #tab, 1 do
		tab[i]=" "..tab[i].."%*"
	end

return tab
end

function M.swspace(x)
local tab = M.copy(x)

	for i = 1, #tab, 1 do
		tab[i]=tab[i].."%*".." "
	end

return tab
end
--------------------------------------------------------------------------------------------------------------------------------------------
function M.portscheck(y, briAblePor)
local num = M.split(y, "[+-]?%d+")
local word = M.split(y, "[%w_]+")
local tab = {}
local k = briAblePor --how many ports could be bridged
local p = 0 -- loop variable
local i = 1 -- loop variable
local zahler = 1 -- loop variable
while zahler<=k do
checking=0
	while checking<1 do
	p=p+1
		if zahler>=5 then
			for j = 1, p, 1 do
				if num[i] ~= string.format("%s", j) and zahler <= k and j~=p then
					tab[p] = "no bridge"
				elseif num[i] ~= string.format("%s", j) and zahler <= k and j==p and num[i]~=nil then
					tab[p] = "no bridge"
					zahler = zahler +1
				elseif num[i] == string.format("%s", j) and zahler <= k then
					tab[p] = word[i]
					checking=1
					zahler = zahler +1
				elseif zahler >= k or num[i]==nil then
					tab[p] = "no bridge"
					checking=1
					zahler = zahler +1
				end
			end
		else
			for j = 1, p, 1 do
				if num[i] ~= string.format("%s", j-1) and zahler <= k and j~=p then
					tab[p] = "no bridge"
				elseif num[i] ~= string.format("%s", j-1) and zahler <= k and j==p and num[i]~=nil then
					tab[p] = "no bridge"
					zahler = zahler +1
				elseif num[i] == string.format("%s", j-1) and zahler <= k then
					tab[p] = word[i]
					checking=1
					zahler = zahler +1
				elseif zahler >= k or num[i]==nil then
					tab[p] = "no bridge"
					checking=1
					zahler = zahler +1
				end
			end
		end
	end

if zahler <= k then
i=i+1
end
end
return tab
end
-----------------------------------------Need a name---------------
function M.portsort(briableport)
tab={}
for i=1, briableport, 1 do
	if i <= 4 then
	table.insert(tab, string.format("%s", "Port "..i))
	else
	table.insert(tab, string.format("%s", "Wireless 5G"))
	end
end
return tab
end
--------------------------------------------------------------------
function M.resultcheck(x)

tab=M.copy(x)
a = string.format("%s", tab[1])
	for k = 2, #tab, 1 do
		a = a..string.format("%s", tab[k])
	end
	return a
end
----------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------
return M