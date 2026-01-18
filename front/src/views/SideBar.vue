<template>
  <el-aside class="sidebar">
    <el-scrollbar>
      <el-menu
        @select="handleMenuSelect"
        class="menu"
        :default-active="defaultActive"
        :collapse="isCollapse"
      >
        <div class="sidebar-header">
          <h1>设备列表</h1>
        </div>
        
        <!-- 添加设备按钮 -->
        <div class="add-device-btn" v-if="!isCollapse">
          <el-button type="primary" @click="showAddDeviceDialog" :icon="Plus">
            添加设备
          </el-button>
        </div>
        <div class="add-device-btn-collapse" v-else>
          <el-button type="primary" circle @click="showAddDeviceDialog" :icon="Plus" />
        </div>
        
        <!-- 动态生成菜单项 -->
        <el-menu-item
          v-for="deviceName in deviceList"
          :key="deviceName"
          :index="`/device/${deviceName}`"
          class="device-menu-item"
        >
          <el-icon>
            <component :is="Cpu" />
          </el-icon>
          <template #title>
            <div class="menu-item-content">
              <span>{{ deviceName }}</span>
              <div v-if="!isCollapse" class="menu-item-actions">
                <el-button 
                  link
                  size="small" 
                  :icon="Edit"
                  @click.stop="handleEditDevice(deviceName)"
                />
                <el-button 
                  link
                  size="small" 
                  :icon="Delete"
                  @click.stop="handleDeleteDevice(deviceName)"
                />
              </div>
            </div>
          </template>
        </el-menu-item>
      </el-menu>
    </el-scrollbar>
  </el-aside>

  <el-container>
    <el-main>
      <el-scrollbar>
        <AppHeader />
        <router-view />
      </el-scrollbar>
    </el-main>
  </el-container>
  
  <!-- 添加/编辑设备对话框 -->
  <AddDeviceDialog 
    v-model:visible="addDeviceDialogVisible" 
    :channel-id="editingChannelId"
    @success="handleDeviceAdded"
    @close="editingChannelId = null"
  />
</template>

<script lang="ts" setup>
import { useRouter } from "vue-router";
import menuRouter from "@/router/index";
import { Cpu, Plus, Delete, Edit } from "@element-plus/icons-vue";
import { onMounted, ref, watch } from "vue";
import { isCollapse } from "@/components/header/isCollapse";
import AppHeader from "@/components/header/AppHeader.vue";
import AddDeviceDialog from "@/components/device/AddDeviceDialog.vue";
import { deleteChannel, getChannelList, getChannel } from "@/api/channelApi";
import { getDeviceList } from "@/api/deviceApi";
import { ElMessage, ElMessageBox } from "element-plus";
import Device from "@/views/Device.vue";

const router = useRouter();
const defaultActive = ref("/");
const addDeviceDialogVisible = ref(false);
const editingChannelId = ref<number | null>(null);
const deviceList = ref<string[]>([]);

// 从后端获取设备列表
const fetchDeviceList = async () => {
  try {
    deviceList.value = await getDeviceList();
  } catch (error) {
    console.error('获取设备列表失败:', error);
  }
};

onMounted(async () => {
  // 获取设备列表
  await fetchDeviceList();
  
  const isCollapseValue = localStorage.getItem("isCollapse");
  if (isCollapseValue) {
    isCollapse.value = isCollapseValue === "true";
  }
  
  if (deviceList.value.length > 0) {
    // 从 localStorage 中恢复选中的路由
    const savedActive = localStorage.getItem("activeRoute");
    
    // 验证保存的路由是否仍然存在
    const deviceExists = savedActive && deviceList.value.some(d => `/device/${d}` === savedActive);
    
    if (deviceExists) {
      defaultActive.value = savedActive;
    } else {
      // 使用第一个设备作为默认选中
      defaultActive.value = `/device/${deviceList.value[0]}`;
      localStorage.setItem("activeRoute", defaultActive.value);
    }
    
    // 确保导航到选中的路由
    router.push(defaultActive.value);
  }
});

const handleMenuSelect = (path: string) => {
  // 保存选中的路由到 localStorage
  localStorage.setItem("activeRoute", path);
  // 导航到选中的路由
  router.push(path);
};

// 显示添加设备对话框
const showAddDeviceDialog = () => {
  editingChannelId.value = null;  // 重置为新增模式
  addDeviceDialogVisible.value = true;
};

// 设备添加/编辑成功后刷新路由
const handleDeviceAdded = async (deviceName: string, isEdit?: boolean, oldName?: string) => {
  if (isEdit && oldName) {
    // 编辑模式：如果名称改变，需要更新路由
    if (oldName !== deviceName) {
      // 移除旧路由
      menuRouter.removeRoute(oldName);
      
      // 找到旧路由在列表中的位置（通过获取所有路由）
      const routes = menuRouter.getRoutes();
      
      // 添加新路由
      const route = {
        path: `/device/${deviceName}`,
        name: deviceName,
        meta: {
          title: deviceName
        },
        component: () => import("@/views/Device.vue")
      };
      menuRouter.addRoute(route);
    }
    // 导航到新设备名称
    const newPath = `/device/${deviceName}`;
    defaultActive.value = newPath;
    localStorage.setItem("activeRoute", newPath);
    router.push(newPath);
  } else {
    // 新增模式：添加新路由
    const route = {
      path: `/device/${deviceName}`,
      name: deviceName,
      meta: {
        title: deviceName
      },
      component: () => import("@/views/Device.vue")
    };
    menuRouter.addRoute(route);
    
    // 导航到新设备
    const newPath = `/device/${deviceName}`;
    defaultActive.value = newPath;
    localStorage.setItem("activeRoute", newPath);
    router.push(newPath);
  }
};

// 编辑设备
const handleEditDevice = async (deviceName: string) => {
  try {
    // 获取对应的channel_id
    const channels = await getChannelList();
    const channel = channels.find(c => c.name === deviceName);
    
    if (channel) {
      editingChannelId.value = channel.id;
      addDeviceDialogVisible.value = true;
    } else {
      ElMessage.error('未找到对应的通道');
    }
  } catch (error: any) {
    ElMessage.error('获取通道信息失败: ' + error.message);
  }
};

// 删除设备
const handleDeleteDevice = async (deviceName: string) => {
  try {
    await ElMessageBox.confirm(
      `确定要删除设备 "${deviceName}" 吗？删除后将无法恢复。`,
      '删除确认',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning',
      }
    );
    
    // 从通道列表获取对应的channel_id
    const channels = await getChannelList();
    const channel = channels.find(c => c.name === deviceName);
    
    if (channel) {
      await deleteChannel(channel.id);
      
      ElMessage.success('设备删除成功');
      
      // 刷新页面以更新路由列表
      window.location.reload();
    } else {
      ElMessage.error('未找到对应的通道');
    }
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败: ' + error.message);
    }
  }
};
</script>

<style scoped>
.el-container {
  padding: 0;
  margin: 0;
  width: 100%;
  height: 100vh; /* 确保占满视口 */
}

.el-aside {
  height: 100vh;
  width: auto;
}

.el-main {
  padding: 0;
  margin: 0px 0px 0px 0px;
}

.sidebar {
  width: auto;
  height: 100vh;
  background-color: #f8f9ff;
}

.sidebar-header {
  text-align: center;
  margin-top: 10px;
  margin-bottom: 10px;
}

.sidebar-header h1 {
  margin: 0;
  font-size: 1.5em;
  color: #333;
  transition: opacity 0.1s ease;
}

.add-device-btn {
  padding: 10px 15px;
  text-align: center;
}

.add-device-btn .el-button {
  width: 100%;
}

.add-device-btn-collapse {
  padding: 10px;
  text-align: center;
}

/* el-scrollbar 样式调整 */
.el-scrollbar {
  height: 100%; /* 让 el-scrollbar 占满侧边栏高度 */
}

.el-scrollbar__wrap {
  overflow-x: hidden; /* 隐藏横向滚动条 */
}

.el-menu {
  width: 200px;
  border-right: none;
  position: relative;
  background-color: transparent !important;
  will-change: width;

  .is-active {
    background-color: #dbeafe !important; /* 浅蓝色 */
    color: #333 !important;
  }

  /* 折叠状态 */
  &.el-menu--collapse {
    width: 60px;
    & h1 {
      display: none;
    }
  }
}

.menu {
  width: 200px;
  border-right: none;
  background-color: transparent;
}

.borderless-button {
  border: none;
  background-color: transparent;
  font-size: 20px;
  margin-right: 5px;
}

.menu-item-content {
  display: flex;
  align-items: center;
  width: 100%;
  position: relative;
}

.menu-item-content > span {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
  max-width: calc(100% - 60px);
}

.menu-item-actions {
  display: flex;
  flex-shrink: 0;
  gap: 0;
  position: absolute;
  right: 0;
}

.menu-item-actions .el-button {
  color: #909399;
  padding: 2px 2px;
  margin-left: 0;
}

.menu-item-actions .el-button:hover {
  color: #409EFF;
}
</style>

