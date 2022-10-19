clang_path=clang
ld_path=wasm-ld

## WASM2C Folder
wasm2c_folder=../../../wasm2c
bin_folder=../../../bin
simde_folder=../../../third_party/simde

curfile="demo"

param=37
if [[ $1 ]]
  then
    echo "Using supplied parameter $1"
    param=$1
else 
    echo "Using default parameter $param"
fi

echo "[X] Build $curfile.c"
echo " - [X] Compiling to WASM with clang"
# Tested with clang 15
$clang_path -O3 --target=wasm32-unknown-unknown-wasm -msimd128 -c -o $curfile.int.wasm $curfile.c 
$ld_path -m wasm32 --export-all --no-entry --growable-table --stack-first -z stack-size=1048576 $curfile.int.wasm -o $curfile.wasm

if [ $? -eq 0 ]; then
    echo " - [X] Running wasm2wat"
    # clean up previous file
    rm $curfile.wasm2c.wat 2> /dev/null

    $bin_folder/wasm2wat $curfile.wasm > $curfile.wasm2c.wat
    # read -p "Press enter to continue"
    echo " - [X] Running wasm2c"
    # clean up previous files
    rm $curfile.wasm2c.c 2> /dev/null
    rm $curfile.wasm2c.h 2> /dev/null

    $bin_folder/wasm2c $curfile.wasm -vv -o $curfile.wasm2c.c &> $curfile.wasm2c.verbose_log.txt
    if [ $? -eq 0 ]; then
        echo " - [X] Emitting LLVM IR"

        $clang_path -D ENABLESIMD -I$wasm2c_folder -I$simde_folder -S -emit-llvm -mavx \
                    $curfile.main.c                  \
                    $curfile.wasm2c.c                \
                    $wasm2c_folder/wasm-rt-impl.c    
        
        echo " - [X] Building wasm2c output"
        $clang_path -D ENABLESIMD -I$wasm2c_folder -I$simde_folder -lm -o $curfile.wasm2c.out -mavx \
                    $curfile.main.c                  \
                    $curfile.wasm2c.c                \
                    $wasm2c_folder/wasm-rt-impl.c    
        if [ $? -eq 0 ]; then
            # read -p "Press enter to continue"
            echo " - [X] Saving objdump of binary"
            objdump -d $curfile.wasm2c.out > $curfile.wasm2c.out.objdump.txt

            echo " - [X] Running Output with param $param"
            echo ./$curfile.wasm2c.out $param
            ./$curfile.wasm2c.out $param
            if [ $? -eq 0 ]; then
                echo " "
            else 
                echo " - [ERROR] Issue running Output"
                echo "Command: $curfile.wasm2c.out $param"
            fi
        else 
            echo " - [ERROR] Error building shared library for $curfile"
            echo "Command: $clang_path -I$wasm2c_folder -I$simde_folder -o $curfile.wasm2c.out -mavx $curfile.main.c $curfile.wasm2c.c $wasm2c_folder/wasm-rt-impl.c"
        fi
    else 
        echo " - [ERROR] Error with wasm2c - check log: ./$curfile.wasm2c.verbose_log.txt"
        echo "   Command: $bin_folder/wasm2c $curfile.wasm -vv -o $curfile.wasm2c.c "
        $bin_folder/wasm2c $curfile.wasm -vv -o $curfile.wasm2c.c
    fi
else 
    echo " - [ERROR] Error compiling to WASM with clang"
    echo "Command: $clang_apth -O3 --target=wasm32-unknown-unknown-wasm -msimd128 -c -o $curfile.int.wasm $curfile.c "
    echo "Command: $ld_path -m wasm32 --export-all --no-entry --growable-table --stack-first -z stack-size=1048576 $curfile.int.wasm -o $curfile.wasm"
fi