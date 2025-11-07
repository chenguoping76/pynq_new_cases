from pynq import MMIO
import numpy as np

class PWM:
    """PYNQ PWM驱动类，封装PWM控制器的基本操作"""
    
    # 寄存器偏移量（与C头文件定义保持一致）
    PWM_AXI_CTRL_REG_OFFSET = 0
    PWM_AXI_PERIOD_REG_OFFSET = 8
    PWM_AXI_DUTY_REG_OFFSET = 64
    
    def __init__(self, base_addr, device_name="PWM"):
        """初始化PWM控制器
        
        参数:
            base_addr: PWM控制器的基地址
            device_name: 设备名称（用于调试）
        """
        self.base_addr = base_addr
        self.device_name = device_name
        # 初始化MMIO，假设寄存器空间大小为128字节（足够覆盖用到的寄存器）
        self.mmio = MMIO(base_addr, 128)
        
    def set_period(self, clocks):
        """设置PWM周期（时钟周期数）
        
        参数:
            clocks: 周期对应的时钟周期数（32位无符号整数）
        """
        if not isinstance(clocks, int) or clocks < 0 or clocks > 0xFFFFFFFF:
            raise ValueError("Invalid clock count (must be 32-bit unsigned integer)")
        self.mmio.write(self.PWM_AXI_PERIOD_REG_OFFSET, clocks)
        
    def get_period(self):
        """获取当前PWM周期（时钟周期数）
        
        返回:
            当前周期值（32位无符号整数）
        """
        return self.mmio.read(self.PWM_AXI_PERIOD_REG_OFFSET)
        
    def set_duty(self, clocks, pwm_index):
        """设置指定PWM通道的占空比（时钟周期数）
        
        参数:
            clocks: 占空比对应的时钟周期数（32位无符号整数）
            pwm_index: PWM通道索引（用于计算寄存器偏移）
        """
        if not isinstance(clocks, int) or clocks < 0 or clocks > 0xFFFFFFFF:
            raise ValueError("Invalid duty clock count (must be 32-bit unsigned integer)")
        if not isinstance(pwm_index, int) or pwm_index < 0:
            raise ValueError("Invalid PWM index (must be non-negative integer)")
        
        # 计算目标寄存器偏移（每个通道占4字节）
        reg_offset = self.PWM_AXI_DUTY_REG_OFFSET + 4 * pwm_index
        self.mmio.write(reg_offset, clocks)
        
    def get_duty(self, pwm_index):
        """获取指定PWM通道的占空比（时钟周期数）
        
        参数:
            pwm_index: PWM通道索引
            
        返回:
            当前占空比时钟数（32位无符号整数）
        """
        if not isinstance(pwm_index, int) or pwm_index < 0:
            raise ValueError("Invalid PWM index (must be non-negative integer)")
            
        reg_offset = self.PWM_AXI_DUTY_REG_OFFSET + 4 * pwm_index
        return self.mmio.read(reg_offset)
        
    def enable(self):
        """使能PWM输出"""
        self.mmio.write(self.PWM_AXI_CTRL_REG_OFFSET, 1)
        
    def disable(self):
        """禁用PWM输出"""
        self.mmio.write(self.PWM_AXI_CTRL_REG_OFFSET, 0)
        
    def self_test(self):
        """执行PWM寄存器自检（类似C语言中的PWM_Reg_SelfTest）
        
        返回:
            True: 自检通过
            False: 自检失败
        """
        try:
            # 保存当前寄存器状态
            orig_ctrl = self.mmio.read(self.PWM_AXI_CTRL_REG_OFFSET)
            orig_period = self.get_period()
            
            # 写入测试值
            self.disable()
            self.set_period(0x12345678)
            
            # 验证写入值
            if self.get_period() != 0x12345678:
                return False
                
            # 测试使能功能
            self.enable()
            if self.mmio.read(self.PWM_AXI_CTRL_REG_OFFSET) != 1:
                return False
                
            self.disable()
            if self.mmio.read(self.PWM_AXI_CTRL_REG_OFFSET) != 0:
                return False
                
            # 恢复原始状态
            self.set_period(orig_period)
            self.mmio.write(self.PWM_AXI_CTRL_REG_OFFSET, orig_ctrl)
            return True
            
        except Exception as e:
            print(f"Self-test failed: {e}")
            return False
            
    def __repr__(self):
        return f"PWM(device_name={self.device_name}, base_addr=0x{self.base_addr:X})"