import { defineStore } from 'pinia';
import { apiHost } from "boot/axios";
import { useQuasar } from "quasar";

export const useHostingStore = defineStore('hosting', {
  state: () => ({
    modulesJSON: [
      {
        name: "module 1",
        isWebModule: false,
        dependentModules: [
          {
            name: "web",
            qualifiedName: "web.xtclang.org",
            available: true,
          },
          {
            name: "Bank",
            qualifiedName: "Bank",
            available: false,
          },
          {
            name: "ecstasy",
            qualifiedName: "ecstasy.xtclang.org",
            available: true,
          },
        ],
      },
      {
        name: "module 2",
        isWebModule: true,
        dependentModules: [
        ],
        issues: [
          "Issue 1",
          "Issue 2",
        ]
      }
    ],

    modulesMap: {},

    $q: useQuasar()
  }),

  getters: {
    modules: (state) => {
      return state.modulesJSON;
    },
  },

  actions: {

    buildMap() {
      this.modulesMap = this.modulesJSON.reduce((acc, cur, index) => {

        var hasMissing = cur.dependentModules.some(
          (dependentModule) => !dependentModule.available
        );
        var hasIssues = (cur.issues != undefined && cur.issues.length > 0);

        acc[cur.name] = {
          "index": index,
          deps: {
            "icon": hasMissing ? "warning" : "verified",
            "displayClass": hasMissing ? "text-negative" : "text-positive",
            "displayText": hasMissing ? "Missing dependencies" : "All dependencies available",
          },
          issues: {
            "icon": hasIssues ? "warning" : "verified",
            "displayClass": hasIssues ? "text-negative" : "text-positive",
            "displayText": hasIssues ? "Issues found" : "All good",
          },
        }
        // acc[cur.name] = cur;
        // acc[cur.name].dependentModules = acc[cur.name].dependentModules.reduce((dacc, dcur) => {
        //   dacc[dcur.qualifiedName] = dcur;
        //   return dacc;
        // }, {});
        return acc;
      }, {})

      console.log("-: " + JSON.stringify(this.modulesMap))
    },

    // checkDeps(deps) {
    //   var hasMissing = deps.some(
    //     (dependentModule) => !dependentModule.available
    //   );

    //   var icon =
    //   var displayClass =
    //   var displayText =

    //   return {
    //     "icon": icon,
    //     "displayClass": displayClass,
    //     "displayText": displayText,
    //   }
    // },

    updateModules() {
      this.$q.loading.show();
      apiHost
        .get("/availableModules")
        .then((response) => {
          this.modulesJSON = response.data;
          this.buildMap();
        })
        .catch(() => {
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Could not fetch modules",
            icon: "report_problem",
          });
        })
        .finally(() => {
          this.$q.loading.hide();
        });
    },

    deleteModule(moduleName) {
      this.$q.loading.show();
      apiHost
        .delete("/module/" + moduleName)
        .then(() => {
          this.updateModules();
        })
        .catch(() => {
          this.$q.loading.hide();
          this.$q.notify({
            color: "negative",
            position: "top",
            message: "Could not delete the module",
            icon: "report_problem",
          });
        });
    }

  },
});
