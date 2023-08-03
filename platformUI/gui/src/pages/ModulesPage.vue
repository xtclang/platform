<template>
  <q-page>
    <q-banner class="bg-negative text-white q-ma-xl" v-if="!userStore.hasUser">
      Please to log in to see your deployed modules
    </q-banner>

    <q-card
      flat
      bordered
      class="rounded-borders q-ma-lg"
      v-if="userStore.hasUser"
    >
      <q-card-section>
        <q-toolbar class="text-primary">
          <q-toolbar-title> Installed modules </q-toolbar-title>
          <q-btn
            round
            dense
            icon="cloud_upload"
            @click="showUploadDialog = true"
          >
            <q-tooltip class="bg-secondary text-bold">
              Install new module!
            </q-tooltip>
          </q-btn>
        </q-toolbar>
      </q-card-section>

      <q-card-section>
        <q-list flat separator>
          <q-item
            v-for="currentModule in hostingStore.modules"
            :key="currentModule.name"
          >
            <q-item-section avatar top>
              <q-icon name="extension" color="brown-12" size="34px" />
            </q-item-section>

            <q-item-section top class="col-3 gt-sm">
              <q-item-label caption v-if="currentModule.isWebModule">
                <q-badge color="secondary">WebApp</q-badge>
              </q-item-label>
              <q-item-label class="q-mt-sm">
                {{ currentModule.name }}
              </q-item-label>
            </q-item-section>

            <q-item-section top>
              <q-expansion-item
                expand-separator
                :icon="hostingStore.modulesMap[currentModule.name].deps.icon"
                :header-class="
                  hostingStore.modulesMap[currentModule.name].deps.displayClass
                "
                :expand-icon-class="
                  hostingStore.modulesMap[currentModule.name].deps.displayClass
                "
                :label="
                  hostingStore.modulesMap[currentModule.name].deps.displayText
                "
              >
                <q-list dense flat separator class="rounded-borders">
                  <q-item
                    v-for="dep in currentModule.dependentModules"
                    :key="dep.name"
                  >
                    <q-item-section avatar>
                      <q-icon
                        :color="dep.available ? 'positive' : 'negative'"
                        :name="dep.available ? 'verified' : 'warning'"
                        size="xs"
                      />
                    </q-item-section>

                    <q-item-section>
                      <q-item-label>{{ dep.name }}</q-item-label>
                      <q-item-label caption>{{
                        dep.qualifiedName
                      }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-expansion-item>
            </q-item-section>

            <q-item-section top>
              <q-expansion-item
                expand-separator
                :icon="hostingStore.modulesMap[currentModule.name].issues.icon"
                :header-class="
                  hostingStore.modulesMap[currentModule.name].issues
                    .displayClass
                "
                :expand-icon-class="
                  hostingStore.modulesMap[currentModule.name].issues
                    .displayClass
                "
                :label="
                  hostingStore.modulesMap[currentModule.name].issues.displayText
                "
              >
                <q-list dense flat separator class="rounded-borders">
                  <q-item v-for="issue in currentModule.issues" :key="issue">
                    <q-item-section>
                      <q-item-label>{{ issue }}</q-item-label>
                    </q-item-section>
                  </q-item>
                </q-list>
              </q-expansion-item>
              <!-- <div class="row">
                <div class="col-1 text-right q-pr-md">
                  <q-icon name="warning" color="red" size="sm" />
                </div>
                <div class="col-11">
                  <q-item-label
                    class="text-red"
                    caption
                    lines="1"
                    v-for="issue in currentModule.issues"
                    :key="issue"
                  >
                    {{ issue }}
                  </q-item-label>
                </div>
              </div> -->
            </q-item-section>

            <q-item-section side>
              <div class="text-primary q-gutter-xs" style="min-width: 20%">
                <q-btn
                  class="gt-xs module-action"
                  size="12px"
                  flat
                  dense
                  round
                  icon="web"
                  :disable="
                    !currentModule.isWebModule || currentModule.hasIssues
                  "
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Create web application
                  </q-tooltip>
                </q-btn>
                <q-btn
                  class="gt-xs module-action"
                  size="12px"
                  flat
                  dense
                  round
                  icon="delete"
                  @click="deleteModule(currentModule.name)"
                >
                  <q-tooltip class="bg-amber-1 text-secondary text-bold">
                    Delete module
                  </q-tooltip>
                </q-btn>
              </div>
            </q-item-section>
          </q-item>
        </q-list>
      </q-card-section>
    </q-card>

    <q-dialog v-model="showUploadDialog" persistent>
      <q-card style="min-width: 350px">
        <q-bar class="bg-primary">
          <q-space />
          <q-btn class="text-white" dense flat icon="close" v-close-popup />
        </q-bar>

        <q-card-section>
          <div class="text-h6">Upload module(s)</div>
        </q-card-section>

        <q-card-section class="q-pt-none">
          <q-uploader
            url="/host/upload"
            label="Select '.xtc' file(s) to upload"
            multiple
            accept=".xtc"
            @uploading="$q.loading.show()"
            @uploaded="hostingStore.updateModules()"
            @failed="$q.loading.hide()"
          />

          <!-- <q-input
            dense
            v-model="address"
            autofocus
            @keyup.enter="prompt = false"
          /> -->
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script>
import { defineComponent, onBeforeMount, ref, watch } from "vue";
import { useUserStore } from "stores/user-store";
import { useHostingStore } from "stores/hosting-store";
import { useQuasar } from "quasar";

export default defineComponent({
  name: "IndexPage",

  setup() {
    const $q = useQuasar();

    const userStore = useUserStore();
    const hostingStore = useHostingStore();
    const showUploadDialog = ref(false);
    const fileToUpload = ref(null);

    onBeforeMount(() => {
      if (userStore.hasUser) {
        hostingStore.updateModules();
      }
      if (process.env.DEV) {
        console.log(`DEV MODE: Build the module map from the mock data`);
        userStore.user = "Mock User";
        console.log(`DEV MODE: Build the module map from the mock data`);
        hostingStore.buildMap();
      }
    });

    watch(
      () => userStore.user,
      () => {
        if (userStore.user != undefined) {
          hostingStore.updateModules();
        }
      }
    );

    function deleteModule(name) {
      $q.dialog({
        title: "Confirm",
        message: "Are you sure you want to delete module `" + name + "`?",
        cancel: true,
        persistent: true,
      }).onOk(() => {
        hostingStore.deleteModule(name);
      });
    }

    return {
      userStore,
      hostingStore,
      showUploadDialog,
      fileToUpload,
      deleteModule,
    };
  },
});
</script>

<style lang="sass">

.module-action.disabled
    color: silver
</style>
