FROM nvcr.io/nvidia/cuda:13.3.0-runtime-ubuntu26.04 as BASE

ENV NVIDIA_DRIVER_CAPABILITIES=all

RUN apt update && apt install sudo -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN locale  # check for UTF-8
RUN sudo apt update && sudo apt install locales && \
    sudo locale-gen en_US en_US.UTF-8 && \
    sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8
RUN locale  # verify settings

RUN sudo apt update && sudo apt install software-properties-common -y && \
    sudo add-apt-repository universe && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sudo apt update && sudo apt install curl -y && \
    export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F'"' '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" && \
    sudo dpkg -i /tmp/ros2-apt-source.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN sudo apt update && \
    sudo apt install ros-lyrical-ros-base -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt -y -qq update && \
    apt -y -qq install \
    parallel \
    ros-lyrical-ros2-control \
    ros-lyrical-ros2-controllers \
    ros-lyrical-ur-robot-driver && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt -y -qq update && \
    apt -y -qq install \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt -y -qq update && \
    apt -y -qq install \
    python3-venv
RUN python3 -m venv --system-site-packages /opt/python
RUN /opt/python/bin/python3 -m pip install torch torchcodec

FROM base AS build

RUN sudo apt update && sudo apt install ros-dev-tools -y&& \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY . /opt/ros/motion/src/motion
RUN bash -c "cd /opt/ros/motion && source /opt/ros/lyrical/setup.bash && /opt/python/bin/python -m colcon build --cmake-args -DPython3_EXECUTABLE=/opt/python/bin/python"

FROM base

COPY --from=build /opt/ros/motion/install /opt/ros/motion/install

RUN echo '#!/bin/bash \n\
set -e -x \n\
source /opt/python/bin/activate \n\
source /opt/ros/lyrical/setup.bash \n\
source /opt/ros/motion/install/setup.bash \n\
if [ "${1}" == "UR20" ]; then \n\
  echo /scaled_joint_trajectory_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur20 robot_ip:=192.168.0.2 use_mock_hardware:=true launch_rviz:=false" "ros2 run motion motion" \n\
elif [ "${1}" == "UR30" ]; then \n\
  echo /scaled_joint_trajectory_controller/joint_trajectory \n\
  parallel --line-buffer --tag --halt now,done=1 --halt now,fail=1 -j 0 ::: "ros2 launch ur_robot_driver ur_control.launch.py ur_type:=ur30 robot_ip:=192.168.0.2 use_mock_hardware:=true launch_rviz:=false" "ros2 run motion motion" \n\
elif [ -z "${1}" ]; then \n\
    bash \n\
else \n\
  "$@" \n\
fi \n\
exit 0' >/entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
