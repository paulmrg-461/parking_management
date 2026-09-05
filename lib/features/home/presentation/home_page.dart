import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final session = state is AuthAuthenticated ? state.session : null;
        return Scaffold(
          appBar: AppBar(title: const Text('Parking Management')),
          body: Center(
            child: session == null
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Welcome, ${session.user.displayName}'),
                        Text('Role: ${session.user.role.name}'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.go('/check-in'),
                          child: const Text('Check-in'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => context.go('/check-out'),
                          child: const Text('Check-out'),
                        ),
                        if (session.user.role.name == 'admin') ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.go('/users'),
                            child: const Text('Manage users'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => context.go('/categories'),
                            child: const Text('Manage categories'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => context.go('/tariffs'),
                            child: const Text('Manage tariffs'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => context.go('/vehicles'),
                            child: const Text('Manage vehicles'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => context.go('/monthly-passes'),
                            child: const Text('Manage monthly passes'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => context.go('/reports'),
                            child: const Text('Reports'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => context.read<AuthCubit>().logout(),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
