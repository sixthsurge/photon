start          = float(input("start: "))
end            = float(input("end: "))
step           = float(input("step: "))
decimal_places = int(input("decimal places: ") )

print("[{0}]".format(
    " ".join([
        f"{{0:.{decimal_places}f}}".format(i * step + start) 
        for i in range(int((end - start) / step + 1))
    ])
))
