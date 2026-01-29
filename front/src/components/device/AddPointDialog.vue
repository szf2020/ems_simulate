<template>
  <el-dialog
    v-model="visible"
    :title="isBatch ? '批量添加测点' : '添加测点'"
    width="560px"
    :close-on-click-modal="false"
    @close="handleClose"
  >
    <el-form
      ref="formRef"
      :model="formData"
      :rules="rules"
      label-width="100px"
      label-position="right"
    >
      <!-- 添加模式切换 -->
      <el-form-item label="添加模式">
        <el-radio-group v-model="isBatch">
          <el-radio :value="false">单个添加</el-radio>
          <el-radio :value="true">批量添加</el-radio>
        </el-radio-group>
      </el-form-item>

      <el-form-item label="测点类型" prop="frame_type">
        <el-select v-model="formData.frame_type" placeholder="选择测点类型" style="width: 100%">
          <el-option label="遥测 (YC)" :value="0" />
          <el-option label="遥信 (YX)" :value="1" />
          <el-option label="遥控 (YK)" :value="2" />
          <el-option label="遥调 (YT)" :value="3" />
        </el-select>
      </el-form-item>

      <!-- 批量模式：数量输入 -->
      <template v-if="isBatch">
        <el-form-item label="添加数量" prop="batchCount">
          <el-input-number v-model="batchCount" :min="1" :max="100" style="width: 100%" />
        </el-form-item>
        <el-form-item label="起始地址" prop="reg_addr">
          <el-input v-model="formData.reg_addr" placeholder="如: 0 或 0x0000" />
        </el-form-item>
        <el-form-item label="编码前缀">
          <el-input v-model="codePrefix" placeholder="如: POINT_" />
        </el-form-item>
        <el-form-item label="名称前缀">
          <el-input v-model="namePrefix" placeholder="如: 测点" />
        </el-form-item>
      </template>

      <!-- 单个模式：编码和名称输入 -->
      <template v-else>
        <el-form-item label="测点编码" prop="code">
          <el-input v-model="formData.code" placeholder="输入测点编码" />
        </el-form-item>

        <el-form-item label="测点名称" prop="name">
          <el-input v-model="formData.name" placeholder="输入测点名称" />
        </el-form-item>

        <el-form-item label="寄存器地址" prop="reg_addr">
          <el-input v-model="formData.reg_addr" placeholder="如: 0x0000 或 0" />
        </el-form-item>
      </template>

      <el-form-item label="从机地址" prop="rtu_addr">
        <el-select v-model="formData.rtu_addr" placeholder="选择从机地址" style="width: 100%">
          <el-option
            v-for="slave in slaveIdList"
            :key="slave"
            :label="`从机 ${slave}`"
            :value="slave"
          />
        </el-select>
      </el-form-item>

      <el-form-item label="功能码" prop="func_code">
        <el-select v-model="formData.func_code" placeholder="选择功能码" style="width: 100%">
          <el-option label="01 - 读线圈" :value="1" />
          <el-option label="02 - 读离散输入" :value="2" />
          <el-option label="03 - 读保持寄存器" :value="3" />
          <el-option label="04 - 读输入寄存器" :value="4" />
          <el-option label="05 - 写单个线圈" :value="5" />
          <el-option label="06 - 写单个寄存器" :value="6" />
        </el-select>
      </el-form-item>

      <el-form-item label="解析码" prop="decode_code">
        <el-select v-model="formData.decode_code" placeholder="选择解析码" style="width: 100%">
          <el-option label="0x10 - 16位无符号(单寄存器)" value="0x10" />
          <el-option label="0x11 - 16位有符号(单寄存器)" value="0x11" />
          <el-option label="0x20 - 16位无符号(高字节在前)" value="0x20" />
          <el-option label="0x21 - 16位有符号(高字节在前)" value="0x21" />
          <el-option label="0x40 - 32位无符号整型" value="0x40" />
          <el-option label="0x41 - 32位有符号整型" value="0x41" />
          <el-option label="0x42 - 32位浮点(ABCD)" value="0x42" />
          <el-option label="0x45 - 32位浮点(CDAB)" value="0x45" />
        </el-select>
      </el-form-item>

      <!-- 系数配置，仅遥测和遥调显示 -->
      <template v-if="[0, 3].includes(formData.frame_type)">
        <el-form-item label="乘法系数" prop="mul_coe">
          <el-input-number v-model="formData.mul_coe" :precision="6" :step="0.1" style="width: 100%" />
        </el-form-item>
        <el-form-item label="加法系数" prop="add_coe">
          <el-input-number v-model="formData.add_coe" :precision="6" :step="1" style="width: 100%" />
        </el-form-item>
      </template>
    </el-form>

    <template #footer>
      <el-button @click="handleClose">取消</el-button>
      <el-button type="primary" :loading="loading" @click="handleSubmit">
        {{ isBatch ? `批量添加 ${batchCount} 个` : '确定' }}
      </el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, reactive, watch, computed } from 'vue';
import type { FormInstance, FormRules } from 'element-plus';
import { ElMessage } from 'element-plus';
import { addPoint, type PointCreateData } from '@/api/deviceApi';

const props = defineProps<{
  modelValue: boolean;
  deviceName: string;
  slaveIdList: number[];
  currentSlaveId?: number;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'success'): void;
}>();

const visible = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
});

const formRef = ref<FormInstance>();
const loading = ref(false);
const isBatch = ref(false);
const batchCount = ref(10);
const codePrefix = ref('POINT_');
const namePrefix = ref('测点');

const formData = reactive<PointCreateData>({
  frame_type: 0,
  code: '',
  name: '',
  rtu_addr: 1,
  reg_addr: '0',
  func_code: 3,
  decode_code: '0x41',
  mul_coe: 1.0,
  add_coe: 0.0,
});

// 根据解析码计算寄存器跨度
const getRegisterSpan = (decodeCode: string): number => {
  // 32位解析码占2个寄存器，16位占1个
  if (['0x40', '0x41', '0x42', '0x43', '0x44', '0x45'].includes(decodeCode)) {
    return 2;
  }
  return 1;
};

const rules = computed<FormRules>(() => ({
  frame_type: [{ required: true, message: '请选择测点类型', trigger: 'change' }],
  code: isBatch.value ? [] : [{ required: true, message: '请输入测点编码', trigger: 'blur' }],
  name: isBatch.value ? [] : [{ required: true, message: '请输入测点名称', trigger: 'blur' }],
  rtu_addr: [{ required: true, message: '请选择从机地址', trigger: 'change' }],
  reg_addr: [{ required: true, message: '请输入寄存器地址', trigger: 'blur' }],
}));

watch(() => props.modelValue, (val) => {
  if (val && props.currentSlaveId) {
    formData.rtu_addr = props.currentSlaveId;
  }
});

const handleClose = () => {
  visible.value = false;
  formRef.value?.resetFields();
  isBatch.value = false;
};

const handleSubmit = async () => {
  try {
    await formRef.value?.validate();
    loading.value = true;
    
    if (isBatch.value) {
      // 批量添加模式
      const startAddr = formData.reg_addr.startsWith('0x') 
        ? parseInt(formData.reg_addr, 16) 
        : parseInt(formData.reg_addr);
      const span = getRegisterSpan(formData.decode_code);
      let successCount = 0;
      
      for (let i = 0; i < batchCount.value; i++) {
        const pointData: PointCreateData = {
          ...formData,
          code: `${codePrefix.value}${String(i + 1).padStart(3, '0')}`,
          name: `${namePrefix.value}${i + 1}`,
          reg_addr: String(startAddr + i * span),
        };
        const success = await addPoint(props.deviceName, pointData);
        if (success) successCount++;
      }
      
      if (successCount === batchCount.value) {
        ElMessage.success(`成功添加 ${successCount} 个测点`);
      } else {
        ElMessage.warning(`成功添加 ${successCount}/${batchCount.value} 个测点`);
      }
      emit('success');
      handleClose();
    } else {
      // 单个添加模式
      const success = await addPoint(props.deviceName, formData);
      if (success) {
        ElMessage.success('添加测点成功');
        emit('success');
        handleClose();
      } else {
        ElMessage.error('添加测点失败');
      }
    }
  } catch (error) {
    console.error('表单验证失败:', error);
  } finally {
    loading.value = false;
  }
};
</script>

<style scoped lang="scss">
:deep(.el-dialog__body) {
  padding-top: 20px;
}
</style>
