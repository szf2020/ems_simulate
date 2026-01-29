"""
异步 Modbus 客户端
用于在同一进程中与异步服务端通信，避免事件循环阻塞
"""

import asyncio
import struct
from typing import List, Optional, Union
from pymodbus.client import AsyncModbusTcpClient
from pymodbus.exceptions import ModbusException
from src.enums.modbus_def import ProtocolType
from src.device.core.message_capture import MessageCapture
from src.enums.modbus_register import Decode


class AsyncModbusClient:
    """
    异步 Modbus 客户端
    使用 pymodbus 的 AsyncModbusTcpClient 避免阻塞事件循环
    """

    def __init__(
        self,
        host: str = "127.0.0.1",
        port: int = 502,
        timeout: float = 1.0,
        retries: int = 1,
        log=None,
    ):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.retries = retries
        self.log = log
        self.client: Optional[AsyncModbusTcpClient] = None
        self.connected = False
        self.message_capture = MessageCapture()

    async def connect(self) -> bool:
        """异步连接到 Modbus 服务器"""
        try:
            self.client = AsyncModbusTcpClient(
                host=self.host,
                port=self.port,
                timeout=self.timeout,
                retries=self.retries,
            )
            self.connected = await self.client.connect()
            if self.connected:
                if self.log:
                    self.log.info(f"异步 Modbus 客户端已连接到 {self.host}:{self.port}")
            else:
                if self.log:
                    self.log.error(f"异步 Modbus 客户端连接失败: {self.host}:{self.port}")
            return self.connected
        except Exception as e:
            if self.log:
                self.log.error(f"异步连接失败: {e}")
            self.connected = False
            return False

    async def disconnect(self) -> None:
        """断开连接"""
        if self.client:
            self.client.close()
            self.connected = False

    async def read_holding_registers(
        self, slave_id: int, address: int, count: int = 1
    ) -> List[int]:
        """异步读取保持寄存器"""
        if not self.connected or not self.client:
            if self.log:
                self.log.error("客户端未连接")
            return []

        try:
            response = await self.client.read_holding_registers(
                address, count, slave=slave_id
            )
            if not response.isError():
                return response.registers
            else:
                if self.log:
                    self.log.error(f"读取保持寄存器错误: {response}")
                return []
        except ModbusException as e:
            if self.log:
                self.log.error(f"Modbus 异常: {e}")
            return []

    async def read_input_registers(
        self, slave_id: int, address: int, count: int = 1
    ) -> List[int]:
        """异步读取输入寄存器"""
        if not self.connected or not self.client:
            return []

        try:
            response = await self.client.read_input_registers(
                address, count, slave=slave_id
            )
            if not response.isError():
                return response.registers
            return []
        except ModbusException as e:
            if self.log:
                self.log.error(f"Modbus 异常: {e}")
            return []

    async def read_coils(
        self, slave_id: int, address: int, count: int = 1
    ) -> List[bool]:
        """异步读取线圈"""
        if not self.connected or not self.client:
            return []

        try:
            response = await self.client.read_coils(address, count, slave=slave_id)
            if not response.isError():
                return response.bits[:count]
            return []
        except ModbusException as e:
            if self.log:
                self.log.error(f"Modbus 异常: {e}")
            return []

    async def read_discrete_inputs(
        self, slave_id: int, address: int, count: int = 1
    ) -> List[bool]:
        """异步读取离散输入"""
        if not self.connected or not self.client:
            return []

        try:
            response = await self.client.read_discrete_inputs(
                address, count, slave=slave_id
            )
            if not response.isError():
                return response.bits[:count]
            return []
        except ModbusException as e:
            if self.log:
                self.log.error(f"Modbus 异常: {e}")
            return []

    async def write_register(
        self, slave_id: int, address: int, value: int
    ) -> bool:
        """异步写入单个寄存器"""
        if not self.connected or not self.client:
            return False

        try:
            response = await self.client.write_register(
                address, value, slave=slave_id
            )
            return not response.isError()
        except ModbusException as e:
            if self.log:
                self.log.error(f"Modbus 写入异常: {e}")
            return False

    async def write_registers(
        self, slave_id: int, address: int, values: List[int]
    ) -> bool:
        """异步写入多个寄存器"""
        if not self.connected or not self.client:
            return False

        try:
            response = await self.client.write_registers(
                address, values, slave=slave_id
            )
            return not response.isError()
        except ModbusException as e:
            if self.log:
                self.log.error(f"Modbus 写入异常: {e}")
            return False

    async def write_coil(
        self, slave_id: int, address: int, value: bool
    ) -> bool:
        """异步写入单个线圈"""
        if not self.connected or not self.client:
            return False

    async def write_coils(
        self, slave_id: int, address: int, values: List[bool]
    ) -> bool:
        """异步写入多个线圈"""
        if not self.connected or not self.client:
            return False

        try:
            response = await self.client.write_coils(
                address, values, slave=slave_id
            )
            return not response.isError()
        except ModbusException as e:
            if self.log:
                self.log.error(f"Modbus 写入异常: {e}")
            return False

    async def read_value_by_address(
        self,
        func_code: int,
        slave_id: int,
        address: int,
        decode: str = "0x41",
    ) -> Optional[Union[int, float]]:
        """
        根据解析码读取寄存器值并解析为指定数据类型
        """
        if not self.connected:
            return None

        # 获取解析码完整信息
        info = Decode.get_info(decode)
        register_cnt = info.register_cnt

        values = None
        registers = None

        # 读取寄存器值
        if func_code == 1:  # 读取线圈
            values = await self.read_coils(slave_id, address, register_cnt)
            if not values:
                return None
            return values[0]
        elif func_code == 2:  # 读取离散输入
            values = await self.read_discrete_inputs(slave_id, address, register_cnt)
            if not values:
                return None
            return values[0]
        elif func_code == 3:  # 读取保持寄存器
            registers = await self.read_holding_registers(slave_id, address, register_cnt)
        elif func_code == 4:  # 读取输入寄存器
            registers = await self.read_input_registers(slave_id, address, register_cnt)
        else:
            if self.log:
                self.log.error(f"Unsupported function code: {func_code}")
            return None

        if not registers:
            return None

        # 将寄存器值打包为字节
        if register_cnt == 4:  # 64位
            packed = struct.pack(">HHHH" if info.is_big_endian else "<HHHH", *registers)
        elif register_cnt == 2:  # 32位
            packed = struct.pack(">HH" if info.is_big_endian else "<HH", *registers)
        else:  # 16位
            value = registers[0]
            if not info.is_big_endian:  # 小端序处理
                value = ((value & 0xFF) << 8) | ((value >> 8) & 0xFF)
            if info.is_signed and value > 0x7FFF:
                value -= 0x10000
            return value
        
        # 使用统一的解包方法
        return Decode.unpack_value(info.pack_format, packed)

    async def write_value_by_address(
        self,
        func_code: int,
        slave_id: int,
        address: int,
        value: Union[int, float],
        decode: str = "0x41",
    ) -> bool:
        """
        根据解析码将值写入寄存器
        """
        if not self.connected:
            return False

        # 获取解析码完整信息
        info = Decode.get_info(decode)
        register_cnt = info.register_cnt
        
        # 使用统一的打包方法
        packed = Decode.pack_value(info.pack_format, value)
        
        # 将打包后的字节转换为寄存器值列表
        if register_cnt == 4:  # 64位
            registers = list(struct.unpack(">HHHH" if info.is_big_endian else "<HHHH", packed))
        elif register_cnt == 2:  # 32位
            registers = list(struct.unpack(">HH" if info.is_big_endian else "<HH", packed))
        else:  # 16位
            val = int(value)
            if info.is_signed and val < 0:
                val = (1 << 16) + val
            registers = [val & 0xFFFF]
            if not info.is_big_endian:  # 小端序处理
                registers[0] = ((registers[0] & 0xFF) << 8) | ((registers[0] >> 8) & 0xFF)

        # 写入寄存器值
        if func_code in [5, 15]:  # 线圈操作
            return await self.write_coils(slave_id, address, [bool(v) for v in registers])
        elif func_code in [6, 16]:  # 寄存器操作
            if func_code == 6 and len(registers) == 1:
                return await self.write_register(slave_id, address, registers[0])
            else:
                return await self.write_registers(slave_id, address, registers)
        else:
            if self.log:
                self.log.error(f"Unsupported function code for writing: {func_code}")
            return False

    def getCapturedMessages(self, limit: int = 100):
        """获取捕获的报文"""
        return self.message_capture.get_messages(limit)

    def clearCapturedMessages(self) -> None:
        """清空捕获的报文"""
        self.message_capture.clear()
