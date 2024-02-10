import { Divider, Tooltip, Transition } from "@mantine/core";
import { Cog, ParkingSquare, RefreshCw } from "lucide-react";
import React, { useEffect, useState } from "react";
import { useNuiEvent } from "../hooks/useNuiEvent";
import Garage from "../icons/garage.svg";
import Tow from "../icons/tow.svg";
import { Vehicle } from "../types/Vehicle";
import { debugData } from "../utils/debugData";
import { fetchNui } from "../utils/fetchNui";
import { isEnvBrowser } from "../utils/misc";
import "./App.css";
import Button from "./Main/Button";
import HeaderText from "./Main/header-text";
import VehicleContainer from "./Main/vehicle-container";

debugData([
  {
    action: "setVisible",
    data: {
      visible: true,
    },
  },
]);

// interface views {
//   [key: string]: React.Component;
// }

const App: React.FC = React.memo(() => {
  const [visible, setVisible] = useState(false);
  const [currentTab, setCurrentTab] = useState("garage");
  const [vehicles, setVehicles] = useState<Vehicle[] | undefined>(undefined);
  const [loading, setLoading] = useState(false);
  const [inImpound, setInImpound] = useState(false);
  useNuiEvent(
    "setVisible",
    (data: { visible: boolean; inImpound: boolean }) => {
      setVisible(data.visible);
      setInImpound(data.inImpound);
    }
  );
  useNuiEvent("nui:state:vehicles", setVehicles);

  useEffect(() => {
    if (!visible) return;

    const keyHandler = (e: KeyboardEvent) => {
      if (["Escape"].includes(e.code)) {
        if (!isEnvBrowser()) fetchNui("hideFrame");
        else setVisible(!visible);
      }
    };

    if (inImpound) {
      setCurrentTab("impound");
    }

    window.addEventListener("keydown", keyHandler);

    return () => window.removeEventListener("keydown", keyHandler);
  }, [visible]);

  const handleButtonClick = (tab: string) => {
    if (!loading) {
      setLoading(true);
      setCurrentTab(tab);
      setTimeout(() => {
        setLoading(false);
      }, 500);
    }
  };

  return (
    <Transition
      mounted={visible}
      transition={"pop"}
      timingFunction="ease"
      duration={400}
    >
      {(styles) => (
        <div
          className="flex w-[100dvw] h-[100dvh] justify-center items-center"
          style={styles}
        >
          <div className="bg-[#25262b] h-[65dvh] w-[50dvw] px-4 py-1 rounded-[2px] overflow-hidden">
            <header className="flex items-center justify-center font-main text-neon text-xl">
              <HeaderText Icon={ParkingSquare} className="mr-auto" size={20} />
              <div className="flex gap-2 mr-auto">
                <Tooltip
                  label="Garage"
                  classNames={{
                    tooltip: "!bg-[#1a1b1e] font-inter text-neon rounded-[2px]",
                  }}
                >
                  <div>
                    <Button
                      svg={Garage}
                      disabled={inImpound}
                      className={`${
                        currentTab === "garage" && "border-neon"
                      } is-dirty`}
                      onClick={() => {
                        handleButtonClick("garage");
                      }}
                    />
                  </div>
                </Tooltip>
                <Tooltip
                  label="Impound"
                  classNames={{
                    tooltip: "!bg-[#1a1b1e] font-inter text-neon rounded-[2px]",
                  }}
                >
                  <div>
                    <Button
                      svg={Tow}
                      className={`${currentTab === "impound" && "border-neon"}`}
                      onClick={() => {
                        handleButtonClick("impound");
                      }}
                    />
                  </div>
                </Tooltip>
              </div>
              <Button
                className={`hover:border-neon !px-3 !py-2`}
                size={16}
                Icon={Cog}
              ></Button>
            </header>

            <Divider my="sm" />

            {loading ? (
              <>
                <div className="w-full h-full flex justify-center items-center">
                  <RefreshCw
                    className="text-neon animate-spin mb-28"
                    size={20}
                    strokeWidth={2.5}
                  />
                </div>
              </>
            ) : (
              <>
                {!!vehicles && (
                  <VehicleContainer
                    inImpound={inImpound}
                    vehicles={
                      currentTab === "garage"
                        ? Object.values(vehicles).filter(
                            (vehicle) => vehicle.location !== "impound"
                          )
                        : Object.values(vehicles).filter(
                            (vehicle) => vehicle.location === "impound"
                          )
                    }
                  />
                )}
              </>
            )}
          </div>
        </div>
      )}
    </Transition>
  );
});

export default App;
