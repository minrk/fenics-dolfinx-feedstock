set -ex

pip check || echo "pip check failed! if it's petsc4py objecting to numpy 1, that's ok"

TEST_DIR=$PWD

# disable clang availability check
if [[ "$target_platform" =~ "osx" ]]; then
  export CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
fi

export PYTHONUNBUFFERED=1

# test packaging
pytest -vs test_dolfinx.py

# exercise a demo
cd $TEST_DIR/python/demo
pytest -vs -k demo_poisson test.py

# run some tests
cd $TEST_DIR/python/test
# subset of tests should exercise dependencies, solvers, partitioners
if [[ "$target_platform" == "linux-aarch64" || "$target_platform" == "linux-ppc64le" ]]; then
  # emulated platforms time out running tests
  TESTS="unit/fem/test_fem_pipeline.py::test_P_simplex unit/mesh/test_mesh_partitioners.py"
else
  TESTS="unit/fem/test_fem_pipeline.py unit/mesh/test_mesh_partitioners.py"
fi

# unit/fem/test_fem_pipeline.py::test_dP_simplex[3-DG-tetrahedron] is failing
# with 4e-6 > 1e-9
if [[ "$target_platform" =~ "osx" ]]; then
  SELECTOR=''
  MPI_SELECTOR=''
else
  SELECTOR=''
  MPI_SELECTOR="${SELECTOR}"
fi
pytest -vs -k "$SELECTOR" $TESTS

if [[ "${target_platform}-${mpi}" == "linux-aarch64-openmpi" ]]; then
  # mpiexec seems to fail on emulated arm with
  # ORTE_ERROR_LOG: Out of resource in file util/show_help.c at line 507
  # --------------------------------------------------------------------------
  # WARNING: Open MPI failed to look up the peer IP address information of
  # a TCP connection that it just accepted.  This should not happen.
  echo "skipping emulated openmpi tests"
else
  mpiexec -n 2 pytest -vs -k "$MPI_SELECTOR" $TESTS
fi

