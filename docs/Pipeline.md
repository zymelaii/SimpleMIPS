# Pipeline

![pipeline](.\Picture\pipeline.png)

## IF stage

![IF_stage](.\Picture/IF_stage.png)

### pre-IF

从inst_sram预取下一条指令(next_pc)

### br_bus

`stall`表示发生load-branch冲突，需要阻塞一个周期；`bd`表示ID阶段为分支或跳转指令，即IF阶段为分支延迟槽指令；`taken`表示跳转是否发生；`target`表示跳转地址

```verilog
typedef struct packed {
    logic  stall;
    logic  bd;
    logic  taken;
    virt_t target;
} br_bus_t;
```

### CP0

`epc`表示在异常处理完成后需要跳转的地址

### 异常

当`fs_pc[1:0] != 0`发生地址错例外-取指，错误地址`fs_pc`放入`exception.badvaddr`

## ID stage


