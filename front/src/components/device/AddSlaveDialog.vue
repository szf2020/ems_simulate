<template>
  <el-dialog
    v-model="visible"
    title="添加从机"
    width="400px"
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
      <el-form-item label="从机地址" prop="slave_id">
        <el-input-number
          v-model="formData.slave_id"
          :min="1"
          :max="255"
          placeholder="输入从机地址 (1-255)"
          style="width: 100%"
        />
      </el-form-item>
      <el-alert
        v-if="existingSlaves.length > 0"
        :title="`已存在的从机: ${existingSlaves.join(', ')}`"
        type="info"
        :closable="false"
        style="margin-bottom: 10px;"
      />
    </el-form>

    <template #footer>
      <el-button @click="handleClose">取消</el-button>
      <el-button type="primary" :loading="loading" @click="handleSubmit">确定</el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue';
import type { FormInstance, FormRules } from 'element-plus';
import { ElMessage } from 'element-plus';
import { addSlave } from '@/api/deviceApi';

const props = defineProps<{
  modelValue: boolean;
  deviceName: string;
  existingSlaves: number[];
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

const formData = reactive({
  slave_id: 1,
});

const validateSlaveId = (_rule: any, value: number, callback: any) => {
  if (props.existingSlaves.includes(value)) {
    callback(new Error(`从机 ${value} 已存在`));
  } else {
    callback();
  }
};

const rules: FormRules = {
  slave_id: [
    { required: true, message: '请输入从机地址', trigger: 'blur' },
    { type: 'number', min: 1, max: 255, message: '从机地址范围: 1-255', trigger: 'blur' },
    { validator: validateSlaveId, trigger: 'blur' }
  ],
};

const handleClose = () => {
  visible.value = false;
  formRef.value?.resetFields();
};

const handleSubmit = async () => {
  try {
    await formRef.value?.validate();
    loading.value = true;
    
    const success = await addSlave(props.deviceName, formData.slave_id);
    if (success) {
      ElMessage.success('添加从机成功');
      emit('success');
      handleClose();
    } else {
      ElMessage.error('添加从机失败，请检查从机地址是否有效');
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
