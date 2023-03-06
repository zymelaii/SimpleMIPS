# Vivado使用

## 重载IP核

右键inst_sram或data_sram，选择re-customize IP

![IP核重载1](.\Picture\IP核重载1.png)

在other options里修改coe file，coe file文件在SimpleMIPS\test\official\func\obj，都是已经编译完成的

![image-20230306115435758](.\Picture\IP核重载2.png)

如果找不到源文件和IP，建议直接在项目里先把所有文件remove，再重新添加回去