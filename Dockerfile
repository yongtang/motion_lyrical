FROM ros:lyrical
RUN apt -y -qq update && \
    apt -y -qq install \
    parallel \
    ros-lyrical-ros2-control \
    ros-lyrical-ros2-controllers
COPY . /opt/ros/motion/src/motion
WORKDIR /opt/ros/motion
RUN apt -y -qq update && \
    apt -y -qq install \
    python3-venv
RUN python3 -m venv --system-site-packages /opt/python
RUN /opt/python/bin/python3 -m pip freeze
RUN (cd /opt/ros/motion && /ros_entrypoint.sh colcon build)
RUN echo '#!/bin/bash \n\
set -e -x \n\
source /opt/ros/lyrical/setup.bash \n\
source /opt/ros/motion/install/setup.bash \n\
source /opt/python/bin/activate \n\
"$@" \n\
exit 0' >/entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
