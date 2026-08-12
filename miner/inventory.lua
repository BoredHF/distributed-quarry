local M={}
function M.isFull(threshold, protected) local used=0;for i=1,16 do if not (protected and protected[i]) and turtle.getItemCount(i)>0 then used=used+1 end end;return used>=threshold end
return M
